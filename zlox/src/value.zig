const std = @import("std");
const logger = @import("./logger.zig");

pub const ValueError = error{
    UnexpectedType,
};

pub const ValueType = enum {
    Bool,
    Number,
    Nil,
};

pub const Value = union(ValueType) {
    Bool: bool,
    Number: f64,
    Nil: void,

    pub fn print(value: Value) void {
        switch (value) {
            .Bool => |b| logger.debug("{}", .{b}),
            .Number => |n| logger.debug("{d}", .{n}),
            .Nil => logger.debug("nil", .{}),
        }
    }

    pub fn asNumber(self: Value) ?f64 {
        switch (self) {
            .Bool, .Nil => return null,
            .Number => |n| return n,
        }
    }

    pub fn isNumber(self: Value) bool {
        switch (self) {
            .Bool, .Nil => return false,
            .Number => return true,
        }
    }
};
