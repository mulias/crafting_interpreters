const std = @import("std");

pub const Value = f64;

pub fn print(value: Value) void {
    std.debug.print("{d}", .{value});
}
