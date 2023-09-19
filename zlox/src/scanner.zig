const std = @import("std");
const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;

pub const Scanner = struct {
    source: []const u8,
    current: usize,
    line: u32,

    pub fn init(source: []const u8) Scanner {
        return Scanner{
            .source = source,
            .current = 0,
            .line = 1,
        };
    }

    pub fn scanToken(self: *Scanner) Token {
        self.skipWhitespace();

        self.source = self.source[self.current..];
        self.current = 0;

        if (self.isAtEnd()) return self.makeToken(.Eof);

        const c = self.advance();

        return switch (c) {
            '(' => self.makeToken(.LeftParen),
            ')' => self.makeToken(.RightParen),
            '{' => self.makeToken(.LeftBrace),
            '}' => self.makeToken(.RightBrace),
            ';' => self.makeToken(.Semicolon),
            ',' => self.makeToken(.Comma),
            '.' => self.makeToken(.Dot),
            '-' => self.makeToken(.Minus),
            '+' => self.makeToken(.Plus),
            '/' => self.makeToken(.Slash),
            '*' => self.makeToken(.Star),
            '!' => self.makeToken(if (self.match('=')) .BangEqual else .Bang),
            '=' => self.makeToken(if (self.match('=')) .EqualEqual else .Equal),
            '<' => self.makeToken(if (self.match('=')) .LessEqual else .Less),
            '>' => self.makeToken(if (self.match('=')) .GreaterEqual else .Greater),
            '"' => self.string(),
            else => {
                if (isAlpha(c)) return self.identifier();
                if (isDigit(c)) return self.number();
                if (c == 0) return self.makeToken(.Eof);
                return self.errorToken("Unexpected character.");
            },
        };
    }

    fn isAtEnd(self: *Scanner) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Scanner) u8 {
        const c = self.peek();
        self.current += 1;
        return c;
    }

    fn skip(self: *Scanner) void {
        self.current += 1;
    }

    fn skipLine(self: *Scanner) void {
        while (self.peek() != '\n' and !self.isAtEnd()) self.skip();
    }

    fn peek(self: *Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current + 1];
    }

    fn match(self: *Scanner, char: u8) bool {
        if (self.isAtEnd() or self.peek() != char) return false;
        self.skip();
        return true;
    }

    fn makeToken(self: *Scanner, tokenType: TokenType) Token {
        return Token{
            .tokenType = tokenType,
            .lexeme = self.source[0..self.current],
            .line = self.line,
        };
    }

    fn errorToken(self: *Scanner, message: []const u8) Token {
        return Token{
            .tokenType = .Error,
            .lexeme = message,
            .line = self.line,
        };
    }

    fn skipWhitespace(self: *Scanner) void {
        while (true) {
            switch (self.peek()) {
                ' ', '\r', '\t' => self.skip(),
                '\n' => {
                    self.line += 1;
                    self.skip();
                },
                '/' => if (self.peekNext() == '/') self.skipLine() else return,
                else => return,
            }
        }
    }

    fn identifier(self: *Scanner) Token {
        while (isAlpha(self.peek()) or isDigit(self.peek())) self.skip();
        return self.makeToken(self.identifierType());
    }

    fn number(self: *Scanner) Token {
        while (isDigit(self.peek())) self.skip();

        if (self.peek() == '.' and isDigit(self.peekNext())) {
            // Consume the ".".
            self.skip();
            while (isDigit(self.peek())) self.skip();
        }

        return self.makeToken(.Number);
    }

    fn string(self: *Scanner) Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            self.skip();
        }

        if (self.isAtEnd()) return self.errorToken("Unterminated string.");

        // The closing quote
        self.skip();
        return self.makeToken(.String);
    }

    fn identifierType(self: *Scanner) TokenType {
        return switch (self.source[0]) {
            'a' => self.checkKeyword(1, "nd", .And),
            'c' => self.checkKeyword(1, "lass", .Class),
            'e' => self.checkKeyword(1, "lse", .Else),
            'f' => switch (self.source[1]) {
                'a' => self.checkKeyword(2, "lse", .False),
                'o' => self.checkKeyword(2, "r", .For),
                'u' => self.checkKeyword(2, "n", .Fun),
                else => .Identifier,
            },
            'i' => self.checkKeyword(1, "f", .If),
            'n' => self.checkKeyword(1, "il", .Nil),
            'o' => self.checkKeyword(1, "r", .Or),
            'p' => self.checkKeyword(1, "rint", .Print),
            'r' => self.checkKeyword(1, "eturn", .Return),
            's' => self.checkKeyword(1, "uper", .Super),
            't' => switch (self.source[1]) {
                'h' => self.checkKeyword(2, "is", .This),
                'r' => self.checkKeyword(2, "ue", .True),
                else => .Identifier,
            },
            'v' => self.checkKeyword(1, "ar", .Var),
            'w' => self.checkKeyword(1, "hile", .While),
            else => .Identifier,
        };
    }

    fn checkKeyword(self: *Scanner, offset: u8, str: []const u8, tokenType: TokenType) TokenType {
        if (self.current != str.len + offset) return .Identifier;
        const sourceSlice = self.source[offset..self.current];
        std.debug.assert(sourceSlice.len == str.len);
        return if (std.mem.eql(u8, sourceSlice, str)) tokenType else .Identifier;
    }
};

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        c == '_';
}
