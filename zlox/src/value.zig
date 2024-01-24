const std = @import("std");
const logger = @import("./logger.zig");
const Obj = @import("./object.zig").Obj;

pub const ValueError = error{
    UnexpectedType,
};

pub const ValueType = enum {
    Bool,
    Number,
    Nil,
    Obj,
};

pub const Value = union(ValueType) {
    Bool: bool,
    Number: f64,
    Nil: void,
    Obj: *Obj,

    pub fn print(value: Value) void {
        switch (value) {
            .Bool => |b| logger.debug("{}", .{b}),
            .Number => |n| logger.debug("{d}", .{n}),
            .Nil => logger.debug("nil", .{}),
            .Obj => |o| logger.debug("{s}", .{o.asString().bytes}),
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

    pub fn isObj(self: Value) bool {
        switch (self) {
            .Obj => return true,
            else => return false,
        }
    }

    pub fn asObj(self: Value) bool {
        std.debug.assert(self.isObj());
        return self.Obj;
    }
};
