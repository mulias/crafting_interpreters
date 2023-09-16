const std = @import("std");

pub fn info(comptime format: []const u8, args: anytype) !void {
    const out = std.io.getStdOut();
    var w = out.writer();
    try w.print(format, args);
}

pub fn debug(comptime format: []const u8, args: anytype) void {
    std.debug.print(format, args);
}
