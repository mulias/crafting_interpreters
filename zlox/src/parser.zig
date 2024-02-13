const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./op_code.zig").OpCode;
const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;
const logger = @import("./logger.zig");
const Value = @import("./value.zig").Value;
const Obj = @import("./object.zig").Obj;
const VM = @import("./vm.zig").VM;
const Compiler = @import("./compiler.zig").Compiler;

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
        if (self.match(.Var)) {
            try self.varDeclaration();
        } else {
            try self.statement();
        }

        if (self.panicMode) self.syncronize();
    }

    pub fn statement(self: *Parser) !void {
        if (self.match(.Print)) {
            try self.printStatement();
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
        if (!self.hadError) self.chunk().disassemble("code");
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

    fn varDeclaration(self: *Parser) !void {
        self.consume(.Identifier, "Expect varaible name.");

        if (self.compiler.isGlobalScope()) {
            const name = try Obj.String.copy(self.vm, self.previous.lexeme);
            try self.varDeclarationInitializer();
            try self.emitConstant(.DefineGlobal, name.obj.value());
        } else {
            const declared = try self.declareLocalVariable(self.previous);
            if (!declared) return;

            try self.varDeclarationInitializer();

            var local = self.compiler.locals.pop();
            local.markInitialized();
            try self.compiler.locals.append(local);
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
            .RightParen,
            .LeftBrace,
            .RightBrace,
            .Comma,
            .Bang,
            .BangEqual,
            .Equal,
            .Semicolon,
            .Identifier,
            .String,
            .Number,
            .And,
            .Class,
            .Else,
            .False,
            .For,
            .Fun,
            .If,
            .Nil,
            .Or,
            .Print,
            .Return,
            .Super,
            .This,
            .True,
            .Var,
            .While,
            .Error,
            .Eof,
            => .None,

            .EqualEqual => .Equality,

            .Greater,
            .GreaterEqual,
            .Less,
            .LessEqual,
            => .Comparison,

            .LeftParen,
            .Dot,
            => .Call,

            .Minus,
            .Plus,
            => .Term,

            .Slash,
            .Star,
            => .Factor,
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
            .And, .Class, .Else, .False, .For, .Fun, .If, .Nil, .Or => {},
            .Print, .Return, .Super, .This, .True, .Var, .While, .Error => {},
            .Eof => {},
        }

        self.errorAtPrevious("Expected expression.");
    }

    fn chunk(self: *Parser) *Chunk {
        return self.vm.chunk;
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

    fn makeConstant(self: *Parser, value: Value) !u8 {
        const idx = try self.chunk().addConstant(value);
        if (idx > std.math.maxInt(u8)) {
            self.errorAtPrevious("Too many constants in one chunk.");
            return 0;
        }

        return @as(u8, @intCast(idx));
    }

    fn declareLocalVariable(self: *Parser, name: Token) !bool {
        self.compiler.addLocal(name) catch |err| switch (err) {
            error.VariableNameUsedInScope => {
                self.errorAtPrevious("Already a variable with this name in this scope.");
                return false;
            },
            error.OutOfMemory => return error.OutOfMemory,
        };
        return true;
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
