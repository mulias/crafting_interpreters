const std = @import("std");
const Scanner = @import("./scanner.zig").Scanner;
const Parser = @import("./parser.zig").Parser;
const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;
const logger = @import("./logger.zig");
const VM = @import("./vm.zig").VM;

pub fn compile(vm: *VM, source: []const u8) !void {
    var parser = Parser.init(vm, source);

    parser.advance();

    while (!parser.match(TokenType.Eof)) {
        try parser.declaration();
    }

    parser.consume(TokenType.Eof, "Expect end of expression.");

    try parser.end();

    if (parser.hadError) return error.CompileError;
}
