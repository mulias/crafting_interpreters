const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./chunk.zig").OpCode;
const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;
const logger = @import("./logger.zig");
const Value = @import("./value.zig").Value;

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
const CompilerError = error{
    // Can happen when we try to emit bytecode or constants
    OutOfMemory,
    // Can happen when we try to parse floats
    InvalidCharacter,
};

pub const Parser = struct {
    scanner: *Scanner,
    chunk: *Chunk,
    current: Token,
    previous: Token,
    hadError: bool,
    panicMode: bool,

    pub fn init(scanner: *Scanner, chunk: *Chunk) Parser {
        return Parser{
            .scanner = scanner,
            .chunk = chunk,
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

    pub fn expression(self: *Parser) !void {
        try self.parsePrecedence(.Assignment);
    }

    pub fn end(self: *Parser) !void {
        try self.emitReturn();
        if (!self.hadError) self.chunk.disassemble("code");
    }

    fn number(self: *Parser) !void {
        const value = try std.fmt.parseFloat(f64, self.previous.lexeme);
        try self.emitConstant(.{ .Number = value });
    }

    fn literal(self: *Parser) !void {
        switch (self.previous.tokenType) {
            .True => try self.emitOp(.True),
            .False => try self.emitOp(.False),
            .Nil => try self.emitOp(.Nil),
            else => self.errorAtPrevious("Unexpected literal"),
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
            else => self.errorAtPrevious("Unexpected binary operator"),
        }
    }

    fn parsePrecedence(self: *Parser, precedence: Precedence) CompilerError!void {
        self.advance();
        try self.parseAsPrefix(self.previous.tokenType);

        while (self.currentTokenPrecedence().isGreaterThan(precedence)) {
            self.advance();
            try self.parseAsInfix(self.previous.tokenType);
        }
    }

    fn tokenPrecedence(tokenType: TokenType) Precedence {
        return switch (tokenType) {
            // Single-character tokens.
            .LeftParen => .Call,
            .RightParen, .LeftBrace, .RightBrace, .Comma => .None,
            .Dot => .Call,
            .Minus, .Plus => .Term,
            .Semicolon => .None,
            .Slash, .Star => .Factor,

            // One or two character tokens.
            .Bang, .BangEqual, .Equal, .EqualEqual, .Greater => .None,
            .GreaterEqual, .Less, .LessEqual => .None,

            // Literals.
            .Identifier, .String, .Number => .None,

            // Keywords.
            .And, .Class, .Else, .False, .For, .Fun, .If, .Nil, .Or => .None,
            .Print, .Return, .Super, .This, .True, .Var, .While, .Error => .None,
            .Eof => .None,
        };
    }

    fn currentTokenPrecedence(self: *Parser) Precedence {
        return tokenPrecedence(self.current.tokenType);
    }

    fn parseAsPrefix(self: *Parser, tokenType: TokenType) !void {
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
            .Identifier, .String => {},
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
            // Single-character tokens.
            .LeftParen, .RightParen, .LeftBrace, .RightBrace, .Comma => {},
            .Dot => {},
            .Minus, .Plus => return self.binary(),
            .Semicolon => {},
            .Slash, .Star => return self.binary(),

            // One or two character tokens.
            .Bang, .BangEqual, .Equal, .EqualEqual, .Greater => {},
            .GreaterEqual, .Less, .LessEqual => {},

            // Literals.
            .Identifier, .String, .Number => {},

            // Keywords.
            .And, .Class, .Else, .False, .For, .Fun, .If, .Nil, .Or => {},
            .Print, .Return, .Super, .This, .True, .Var, .While, .Error => {},
            .Eof => {},
        }

        self.errorAtPrevious("Expected expression.");
    }

    fn emitByte(self: *Parser, byte: u8) !void {
        try self.chunk.write(byte, self.previous.line);
    }

    fn emitOp(self: *Parser, op: OpCode) !void {
        try self.chunk.writeOp(op, self.previous.line);
    }

    fn emitReturn(self: *Parser) !void {
        try self.emitOp(.Return);
    }

    fn emitConstant(self: *Parser, value: Value) !void {
        try self.emitOp(.Constant);
        try self.emitByte(try self.makeConstant(value));
    }

    fn makeConstant(self: *Parser, value: Value) !u8 {
        const idx = try self.chunk.addConstant(value);
        if (idx > std.math.maxInt(u8)) {
            self.errorAtPrevious("Too many constants in one chunk.");
            return 0;
        }

        return @as(u8, @intCast(idx));
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
};
