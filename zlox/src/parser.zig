const std = @import("std");
const Chunk = @import("./chunk.zig").Chunk;
const Compiler = @import("./compiler.zig").Compiler;
const Obj = @import("./object.zig").Obj;
const OpCode = @import("./op_code.zig").OpCode;
const Scanner = @import("scanner.zig").Scanner;
const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;
const VM = @import("./vm.zig").VM;
const Value = @import("./value.zig").Value;
const logger = @import("./logger.zig");

pub const Precedence = enum(u8) {
    None,
    Assignment, // =
    Or, // or
    And, // and
    Equality, // == !=
    Comparison, // < > <= >=
    Term, // + -
    Factor, // * /
    Unary, // ! -
    Call, // . ()
    Primary,

    pub fn next(self: Precedence) Precedence {
        return @as(Precedence, @enumFromInt(@intFromEnum(self) + 1));
    }

    pub fn compare(self: Precedence, other: Precedence) i2 {
        const a = @intFromEnum(self);
        const b = @intFromEnum(other);
        if (a > b) return 1;
        if (a < b) return -1;
        return 0;
    }

    pub fn isGreaterThan(self: Precedence, other: Precedence) bool {
        return self.compare(other) == 1;
    }
};

// Note: We have to spell these out explicitly right now because Zig has
// trouble inferring error sets for recursive functions.
//
// See https://github.com/ziglang/zig/issues/2971
const ParserError = error{
    // Can happen when we try to emit bytecode or constants
    OutOfMemory,
};

pub const Parser = struct {
    vm: *VM,
    compiler: *Compiler,
    scanner: Scanner,
    current: Token,
    previous: Token,
    hadError: bool,
    panicMode: bool,

    pub fn init(compiler: *Compiler, source: []const u8) Parser {
        return Parser{
            .vm = compiler.vm,
            .compiler = compiler,
            .scanner = Scanner.init(source),
            .current = undefined,
            .previous = undefined,
            .hadError = false,
            .panicMode = false,
        };
    }

    pub fn advance(self: *Parser) void {
        self.previous = self.current;

        while (true) {
            self.current = self.scanner.scanToken();
            if (self.current.tokenType != .Error) break;

            self.errorAtCurrent(self.current.lexeme);
        }
    }

    pub fn consume(self: *Parser, tokenType: TokenType, message: []const u8) void {
        if (self.current.tokenType == tokenType) {
            self.advance();
        } else {
            self.errorAtCurrent(message);
        }
    }

    pub fn match(self: *Parser, tokenType: TokenType) bool {
        if (self.check(tokenType)) {
            self.advance();
            return true;
        } else {
            return false;
        }
    }

    pub fn check(self: *Parser, tokenType: TokenType) bool {
        return self.current.tokenType == tokenType;
    }

    pub fn expression(self: *Parser) !void {
        try self.parsePrecedence(.Assignment);
    }

    pub fn declaration(self: *Parser) ParserError!void {
        if (self.match(.Fun)) {
            try self.funDeclaration();
        } else if (self.match(.Var)) {
            try self.varDeclaration();
        } else {
            try self.statement();
        }

        if (self.panicMode) self.syncronize();
    }

    pub fn statement(self: *Parser) ParserError!void {
        if (self.match(.Print)) {
            try self.printStatement();
        } else if (self.match(.If)) {
            try self.ifStatement();
        } else if (self.match(.While)) {
            try self.whileStatement();
        } else if (self.match(.For)) {
            try self.forStatement();
        } else if (self.match(.LeftBrace)) {
            self.beginScope();
            try self.block();
            try self.endScope();
        } else {
            try self.expressionStatement();
        }
    }

    pub fn end(self: *Parser) !void {
        try self.emitReturn();

        if (!self.hadError) {
            const label = self.compiler.function.getName();
            self.chunk().disassemble(label);
        }
    }

    fn beginScope(self: *Parser) void {
        self.compiler.incScope();
    }

    fn endScope(self: *Parser) !void {
        self.compiler.decScope();

        var locals = &self.compiler.locals;
        while (locals.items.len > 0 and
            locals.getLast().depth > self.compiler.scopeDepth)
        {
            try self.emitOp(.Pop);
            _ = locals.pop();
        }
    }

    fn funDeclaration(self: *Parser) !void {
        self.consume(.Identifier, "Expect function name.");

        if (self.compiler.isGlobalScope()) {
            const name = try Obj.String.copy(self.vm, self.previous.lexeme);
            try self.function(.Function);
            try self.emitConstant(.DefineGlobal, name.obj.value());
        } else {
            const declared = try self.declareLocal(self.previous);
            if (!declared) return;
            self.defineLocal();

            try self.function(.Function);
        }
    }

    fn varDeclaration(self: *Parser) !void {
        self.consume(.Identifier, "Expect varaible name.");

        if (self.compiler.isGlobalScope()) {
            const name = try Obj.String.copy(self.vm, self.previous.lexeme);
            try self.varDeclarationInitializer();
            try self.emitConstant(.DefineGlobal, name.obj.value());
        } else {
            const declared = try self.declareLocal(self.previous);
            if (!declared) return;

            try self.varDeclarationInitializer();
            self.defineLocal();
        }
    }

    fn varDeclarationInitializer(self: *Parser) !void {
        if (self.match(.Equal)) {
            try self.expression();
        } else {
            try self.emitOp(.Nil);
        }

        self.consume(.Semicolon, "Expect ';' after variable declaration.");
    }

    fn printStatement(self: *Parser) !void {
        try self.expression();
        self.consume(.Semicolon, "Expect ';' after value.");
        try self.emitOp(.Print);
    }

    fn ifStatement(self: *Parser) ParserError!void {
        self.consume(.LeftParen, "Expect '(' after 'if'.");
        try self.expression();
        self.consume(.RightParen, "Expect ')' after condition.");

        // Jump over if branch when falsey
        const jumpIndex = try self.emitJump(.JumpIfFalse);

        // Remove jump test value when truthy
        try self.emitOp(.Pop);

        // Parse if branch
        try self.statement();

        // Jump over else branch when truthy
        const elseJumpIndex = try self.emitJump(.Jump);

        // Patch the if jump, now that we know where the if branch ends
        self.patchJump(jumpIndex);

        // Remove jump test value when falsey
        try self.emitOp(.Pop);

        // Parse else branch
        if (self.match(.Else)) try self.statement();

        // Patch the else jump, now that we know where the else branch ends
        self.patchJump(elseJumpIndex);
    }

    fn whileStatement(self: *Parser) !void {
        const loopStart = self.chunk().byteCount();

        self.consume(.LeftParen, "Expect '(' after 'while'.");
        try self.expression();
        self.consume(.RightParen, "Expect ')' after condition.");

        const exitJumpIndex = try self.emitJump(.JumpIfFalse);
        try self.emitOp(.Pop);
        try self.statement();
        try self.emitLoop(loopStart);

        self.patchJump(exitJumpIndex);
        try self.emitOp(.Pop);
    }

    fn forStatement(self: *Parser) !void {
        // Scope for optional initializer var.
        self.beginScope();

        self.consume(.LeftParen, "Expect '(' after 'for'.");

        // Optional initializer.
        if (self.match(.Semicolon)) {
            // No initializer
        } else if (self.match(.Var)) {
            try self.varDeclaration();
        } else {
            try self.expressionStatement();
        }

        // Mark the start of the loop, after the initializer and before the
        // condition, body, and increment.
        var startLoopIndex = self.chunk().byteCount();

        // Null if there is no condition expression, otherwise the index of the
        // jump op to get out of the loop when the condition is false.
        var exitJumpIndex: ?usize = null;

        // Null if there is no increment expression, otherwise the index to
        // loop back to after the body is executed.
        var incrementLoopIndex: ?usize = null;

        // Optional condition.
        if (!self.match(.Semicolon)) {
            try self.expression();
            self.consume(.Semicolon, "Expect ';' after loop condition.");

            // Jump out of the loop if the condition is false.
            exitJumpIndex = try self.emitJump(.JumpIfFalse);
            try self.emitOp(.Pop);
        }

        // Optional increment.
        if (!self.match(.RightParen)) {
            // Jump to skip over the increment and execute the body, before
            // looping back to the increment.
            const bodyJumpIndex = try self.emitJump(.Jump);

            // Mark the increment expression, we loop back here after the body.
            incrementLoopIndex = self.chunk().byteCount();

            try self.expression();
            try self.emitOp(.Pop);
            self.consume(.RightParen, "Expect ')' after for clauses.");

            // After the increment go to the start of the loop.
            try self.emitLoop(startLoopIndex);

            // This is the end of the increment expression, so we jump here to
            // get to the body.
            self.patchJump(bodyJumpIndex);
        }

        // The for loop body.
        try self.statement();

        // Loop back to either the increment, or the start of the loop if there
        // is no increment.
        if (incrementLoopIndex) |index| {
            // Loop back to the increment, which will then loop back to the
            // loop start.
            try self.emitLoop(index);
        } else {
            // No increment, go to loop start.
            try self.emitLoop(startLoopIndex);
        }

        // We are now out of the loop, if there was a loop condition then we
        // update the exit jump op to point here.
        if (exitJumpIndex) |index| {
            self.patchJump(index);
            try self.emitOp(.Pop);
        }

        // Clear initializer
        try self.endScope();
    }

    fn expressionStatement(self: *Parser) !void {
        try self.expression();
        self.consume(.Semicolon, "Expect ';' after expression.");
        try self.emitOp(.Pop);
    }

    fn block(self: *Parser) !void {
        while (!self.check(.RightBrace) and !self.check(.Eof)) {
            try self.declaration();
        }

        self.consume(.RightBrace, "Expect '}' after block.");
    }

    fn function(self: *Parser, functionType: Obj.FunctionType) !void {
        try self.initFunctionCompiler(functionType);
        defer self.deinitFunctionCompiler();

        self.beginScope();

        self.consume(.LeftParen, "Expect '(' after function name.");
        self.consume(.RightParen, "Expect ')' after parameters.");
        self.consume(.LeftBrace, "Expect '{' before function body.");
        try self.block();
    }

    fn number(self: *Parser) !void {
        if (std.fmt.parseFloat(f64, self.previous.lexeme)) |value| {
            try self.emitConstant(.Constant, .{ .Number = value });
        } else |e| switch (e) {
            error.InvalidCharacter => {
                self.errorAtPrevious("Could not parse number");
                return;
            },
        }
    }

    fn literal(self: *Parser) !void {
        switch (self.previous.tokenType) {
            .True => try self.emitOp(.True),
            .False => try self.emitOp(.False),
            .Nil => try self.emitOp(.Nil),
            else => self.errorAtPrevious("Unexpected literal"),
        }
    }

    fn string(self: *Parser) !void {
        // Don't include quotes from start/end of string.
        const source = self.previous.lexeme[1 .. self.previous.lexeme.len - 1];
        const value = (try Obj.String.copy(self.vm, source)).obj.value();
        try self.emitConstant(.Constant, value);
    }

    fn variable(self: *Parser, canAssign: bool) !void {
        try self.namedVariable(canAssign);
    }

    fn namedVariable(self: *Parser, canAssign: bool) !void {
        const token = self.previous;

        var setOp: OpCode = undefined;
        var getOp: OpCode = undefined;
        var arg: u8 = undefined;

        const resolvedLocal = self.compiler.resolveLocal(token) catch |err| switch (err) {
            error.NotYetInitialized => {
                self.errorAtPrevious("Can't read local variable in its own initializer.");
                return;
            },
        };

        if (resolvedLocal) |local| {
            setOp = .SetLocal;
            getOp = .GetLocal;
            arg = @as(u8, @intCast(local));
        } else {
            setOp = .SetGlobal;
            getOp = .GetGlobal;

            const nameString = try Obj.String.copy(self.vm, token.lexeme);
            arg = try self.makeConstant(nameString.obj.value());
        }

        if (canAssign and self.match(.Equal)) {
            try self.expression();
            try self.emitUnaryOp(setOp, arg);
        } else {
            try self.emitUnaryOp(getOp, arg);
        }
    }

    fn grouping(self: *Parser) !void {
        try self.expression();
        self.consume(.RightParen, "Expect ')' after expression.");
    }

    fn unary(self: *Parser) !void {
        const operatorType = self.previous.tokenType;

        // Compile the operand.
        try self.parsePrecedence(.Unary);

        // Emit the operator instruction.
        switch (operatorType) {
            .Minus => try self.emitOp(.Negate),
            .Bang => try self.emitOp(.Not),
            else => self.errorAtPrevious("Unexpected unary operator"),
        }
    }

    fn binary(self: *Parser) !void {
        const operatorType = self.previous.tokenType;
        try self.parsePrecedence(tokenPrecedence(operatorType));

        switch (operatorType) {
            .Plus => try self.emitOp(.Add),
            .Minus => try self.emitOp(.Subtract),
            .Star => try self.emitOp(.Multiply),
            .Slash => try self.emitOp(.Divide),
            .EqualEqual => try self.emitOp(.Equal),
            .Greater => try self.emitOp(.Greater),
            .GreaterEqual => {
                try self.emitOp(.Less);
                try self.emitOp(.Not);
            },
            .Less => try self.emitOp(.Less),
            .LessEqual => {
                try self.emitOp(.Greater);
                try self.emitOp(.Not);
            },
            else => self.errorAtPrevious("Unexpected binary operator"),
        }
    }

    fn and_(self: *Parser) !void {
        const endJumpIndex = try self.emitJump(.JumpIfFalse);

        try self.emitOp(.Pop);
        try self.parsePrecedence(.And);

        self.patchJump(endJumpIndex);
    }

    fn or_(self: *Parser) !void {
        const elseJumpIndex = try self.emitJump(.JumpIfFalse);
        const endJumpIndex = try self.emitJump(.Jump);

        self.patchJump(elseJumpIndex);
        try self.emitOp(.Pop);

        try self.parsePrecedence(.Or);
        self.patchJump(endJumpIndex);
    }

    fn parsePrecedence(self: *Parser, precedence: Precedence) ParserError!void {
        self.advance();

        const canAssign = !precedence.isGreaterThan(Precedence.Assignment);

        try self.parseAsPrefix(self.previous.tokenType, canAssign);

        while (self.currentTokenPrecedence().isGreaterThan(precedence)) {
            self.advance();
            try self.parseAsInfix(self.previous.tokenType);
        }

        if (canAssign and self.match(.Equal)) {
            self.errorAtPrevious("Invalid assignment target.");
        }
    }

    fn tokenPrecedence(tokenType: TokenType) Precedence {
        return switch (tokenType) {
            .LeftParen, .Dot => .Call,
            .Slash, .Star => .Factor,
            .Minus, .Plus => .Term,
            .Greater, .GreaterEqual, .Less, .LessEqual => .Comparison,
            .BangEqual, .EqualEqual => .Equality,
            .And => .And,
            .Or => .Or,
            else => .None,
        };
    }

    fn currentTokenPrecedence(self: *Parser) Precedence {
        return tokenPrecedence(self.current.tokenType);
    }

    fn parseAsPrefix(self: *Parser, tokenType: TokenType, canAssign: bool) !void {
        switch (tokenType) {
            // Single-character tokens.
            .LeftParen => return self.grouping(),
            .RightParen, .LeftBrace, .RightBrace, .Comma, .Dot => {},
            .Minus, .Bang => return self.unary(),
            .Plus, .Semicolon, .Slash, .Star => {},

            // One or two character tokens.
            .BangEqual, .Equal, .EqualEqual, .Greater => {},
            .GreaterEqual, .Less, .LessEqual => {},

            // Literals.
            .Identifier => return self.variable(canAssign),
            .String => return self.string(),
            .Number => return self.number(),

            // Keywords.
            .True, .False, .Nil => return self.literal(),
            .And, .Class, .Else, .For, .Fun, .If, .Or => {},
            .Print, .Return, .Super, .This, .Var, .While, .Error => {},
            .Eof => {},
        }

        self.errorAtPrevious("Expected expression.");
    }

    pub fn parseAsInfix(self: *Parser, tokenType: TokenType) !void {
        switch (tokenType) {
            .Minus,
            .Plus,
            .Slash,
            .Star,
            .EqualEqual,
            .Greater,
            .GreaterEqual,
            .Less,
            .LessEqual,
            => return self.binary(),

            .LeftParen, .RightParen, .LeftBrace, .RightBrace, .Comma => {},
            .Dot => {},
            .Semicolon => {},

            .Bang,
            .Equal,
            .BangEqual,
            => {},

            // Literals.
            .Identifier, .String, .Number => {},

            // Keywords.
            .And => return self.and_(),
            .Or => return self.or_(),
            .Class, .Else, .False, .For, .Fun, .If, .Nil => {},
            .Print, .Return, .Super, .This, .True, .Var, .While, .Error => {},
            .Eof => {},
        }

        self.errorAtPrevious("Expected expression.");
    }

    fn chunk(self: *Parser) *Chunk {
        return &self.compiler.function.chunk;
    }

    fn emitByte(self: *Parser, byte: u8) !void {
        try self.chunk().write(byte, self.previous.line);
    }

    fn emitOp(self: *Parser, op: OpCode) !void {
        try self.chunk().writeOp(op, self.previous.line);
    }

    fn emitReturn(self: *Parser) !void {
        try self.emitOp(.Return);
    }

    fn emitUnaryOp(self: *Parser, op: OpCode, byte: u8) !void {
        try self.emitOp(op);
        try self.emitByte(byte);
    }

    fn emitConstant(self: *Parser, op: OpCode, value: Value) !void {
        try self.emitOp(op);
        try self.emitByte(try self.makeConstant(value));
    }

    fn emitLoop(self: *Parser, loopStart: usize) !void {
        try self.emitOp(.Loop);

        const offset = self.chunk().byteCount() - loopStart + 2;
        if (offset > std.math.maxInt(u16)) {
            self.errorAtPrevious("Loop body too large.");
        }

        try self.chunk().writeShort(@as(u16, @intCast(offset)), self.previous.line);
    }

    fn emitJump(self: *Parser, op: OpCode) !usize {
        try self.emitOp(op);
        // Dummy operands that will be patched later
        try self.emitByte(0xff);
        try self.emitByte(0xff);
        return self.chunk().byteCount() - 2;
    }

    fn patchJump(self: *Parser, offset: usize) void {
        std.debug.assert(self.chunk().get(offset) == 0xff);
        std.debug.assert(self.chunk().get(offset + 1) == 0xff);

        const jump = self.chunk().byteCount() - offset - 2;

        if (jump > std.math.maxInt(u16)) {
            self.errorAtPrevious("Too much code to jump over.");
        }

        self.chunk().updateShort(offset, @as(u16, @intCast(jump)));
    }

    fn makeConstant(self: *Parser, value: Value) !u8 {
        const idx = try self.chunk().addConstant(value);
        if (idx > std.math.maxInt(u8)) {
            self.errorAtPrevious("Too many constants in one chunk.");
            return 0;
        }

        return @as(u8, @intCast(idx));
    }

    // Add a local variable.
    fn declareLocal(self: *Parser, name: Token) !bool {
        self.compiler.addLocal(name) catch |err| switch (err) {
            error.VariableNameUsedInScope => {
                self.errorAtPrevious("Already a variable with this name in this scope.");
                return false;
            },
            error.OutOfMemory => return error.OutOfMemory,
        };
        return true;
    }

    // Finalize the most recently declared local variable. In some cases a
    // local is declared then immediately defined, but in other cases the local
    // is declared, an initializer is parsed, and then the local is defined.
    // This prevents issues such as `var a = a`, since a local can't be defined
    // circularly.
    fn defineLocal(self: *Parser) void {
        self.compiler.locals.items[self.compiler.locals.items.len - 1].markInitialized();
    }

    fn initFunctionCompiler(self: *Parser, functionType: Obj.FunctionType) !void {
        var compiler = try Compiler.init(self.vm, functionType, self.compiler);
        self.compiler = &compiler;
    }

    fn deinitFunctionCompiler(self: *Parser) void {
        if (self.compiler.enclosing) |enclosing| {
            self.compiler.deinit();
            self.compiler = enclosing;
        }
    }

    fn errorAtCurrent(self: *Parser, message: []const u8) void {
        self.errorAt(&self.current, message);
    }

    fn errorAtPrevious(self: *Parser, message: []const u8) void {
        self.errorAt(&self.previous, message);
    }

    fn errorAt(self: *Parser, token: *Token, message: []const u8) void {
        if (self.panicMode) return;
        self.panicMode = true;

        logger.warn("[line {}] Error", .{token.line});

        switch (token.tokenType) {
            .Eof => {
                logger.warn(" at end", .{});
            },
            .Error => {},
            else => {
                logger.warn(" at '{s}'", .{token.lexeme});
            },
        }

        logger.warn(": {s}\n", .{message});

        self.hadError = true;
    }

    fn syncronize(self: *Parser) void {
        self.panicMode = false;

        while (self.current.tokenType != .Eof) {
            if (self.previous.tokenType == .Semicolon) return;

            switch (self.current.tokenType) {
                .Class, .Fun, .Var, .For, .If, .While, .Print, .Return => {
                    return;
                },
                else => {
                    // Do nothing.
                },
            }

            self.advance();
        }
    }
};
