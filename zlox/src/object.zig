const std = @import("std");
const VM = @import("./vm.zig").VM;
const Value = @import("./value.zig").Value;

pub const Obj = struct {
    objType: Type,

    pub const Type = enum(u8) {
        String,
    };

    pub fn allocate(vm: *VM, comptime T: type, objType: Type) !*Obj {
        const ptr = try vm.allocator.create(T);

        ptr.obj = Obj{
            .objType = objType,
        };

        return &ptr.obj;
    }

    pub fn value(self: *Obj) Value {
        return Value{ .Obj = self };
    }

    pub fn asString(self: *Obj) *String {
        return @fieldParentPtr(String, "obj", self);
    }

    pub const String = struct {
        obj: Obj,
        bytes: []const u8,

        pub fn copy(vm: *VM, bytes: []const u8) !*String {
            const buffer = try vm.allocator.alloc(u8, bytes.len);
            std.mem.copy(u8, buffer, bytes);
            return String.create(vm, buffer);
        }

        pub fn create(vm: *VM, bytes: []const u8) !*String {
            const obj = try Obj.allocate(vm, String, .String);
            const string = obj.asString();
            string.bytes = bytes;
            return string;
        }
    };
};
