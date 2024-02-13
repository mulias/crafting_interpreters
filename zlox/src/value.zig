const std = @import("std");
const Obj = @import("./object.zig").Obj;
const logger = @import("./logger.zig");

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

    pub fn print(value: Value, printer: anytype) void {
        switch (value) {
            .Bool => |b| printer("{}", .{b}),
            .Number => |n| printer("{d}", .{n}),
            .Nil => printer("nil", .{}),
            .Obj => |o| printer("{s}", .{o.asString().bytes}),
        }
    }

    pub fn isEql(a: Value, b: Value) bool {
        if (a.isBool() and b.isBool()) {
            return a.asBool() == b.asBool();
        } else if (a.isNumber() and b.isNumber()) {
            return a.asNumber() == b.asNumber();
        } else if (a.isNil() and b.isNil()) {
            return true;
        } else if (a.isObj() and b.isObj()) {
            return a.asObj().isEql(b.asObj());
        } else {
            return false;
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

    pub fn asObj(self: Value) *Obj {
        std.debug.assert(self.isObj());
        return self.Obj;
    }
};
