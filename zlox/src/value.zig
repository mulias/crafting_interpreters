const std = @import("std");
const logger = @import("./logger.zig");

pub const Value = f64;

pub fn print(value: Value) void {
    logger.debug("{d}", .{value});
}
