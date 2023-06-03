const std = @import("std");
const Scanner = @import("./scanner.zig").Scanner;
const TokenType = @import("./scanner.zig").TokenType;

pub fn compile(source: []const u8) void {
    var scanner = Scanner.init(source);

    var line: u32 = 0;
    while (true) {
        const token = scanner.scanToken();
        if (token.line != line) {
            std.debug.print("{: >4} ", .{token.line});
            line = token.line;
        } else {
            std.debug.print("   | ", .{});
        }
        std.debug.print("{s} '{s}'\n", .{ @tagName(token.tokenType), token.lexeme });

        if (token.tokenType == TokenType.Eof) break;
    }
}
