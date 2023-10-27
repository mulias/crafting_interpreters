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

    pub fn isNumber(self: Value) bool {
        switch (self) {
            .Number => return true,
            else => return false,
        }
    }

    pub fn asNumber(self: Value) f64 {
        std.debug.assert(self.isNumber());
        return self.Number;
    }

    pub fn isBool(self: Value) bool {
        switch (self) {
            .Bool => return true,
            else => return false,
        }
    }

    pub fn asBool(self: Value) bool {
        std.debug.assert(self.isBool());
        return self.Bool;
    }

    pub fn isNil(self: Value) bool {
        switch (self) {
            .Nil => return true,
            else => return false,
        }
    }
};
