const std = @import("std");
const VM = @import("./vm.zig").VM;
const Value = @import("./value.zig").Value;

pub const Obj = struct {
    objType: Type,
    next: ?*Obj,

    pub const Type = enum(u8) {
        String,
    };

    pub fn allocate(vm: *VM, comptime T: type, objType: Type) !*Obj {
        const ptr = try vm.allocator.create(T);

        ptr.obj = Obj{
            .objType = objType,
            .next = vm.objects,
        };

        vm.objects = &ptr.obj;
        return &ptr.obj;
    }

    pub fn destroy(self: *Obj, vm: *VM) void {
        switch (self.objType) {
            .String => self.asString().destroy(vm),
        }
    }

    pub fn value(self: *Obj) Value {
        return Value{ .Obj = self };
    }

    pub fn isEql(a: *Obj, b: *Obj) bool {
        if (a.isString() and b.isString()) {
            // Strings are interned so they can be compared by address
            return a == b;
        } else {
            return false;
        }
    }

    pub fn isString(self: *Obj) bool {
        return self.objType == .String;
    }

    pub fn asString(self: *Obj) *String {
        return @fieldParentPtr(String, "obj", self);
    }

    pub const String = struct {
        obj: Obj,
        bytes: []const u8,

        pub fn copy(vm: *VM, bytes: []const u8) !*String {
            const interned = vm.strings.get(bytes);
            if (interned) |s| return s;

            const buffer = try vm.allocator.alloc(u8, bytes.len);
            std.mem.copy(u8, buffer, bytes);
            return String.create(vm, buffer);
        }

        pub fn create(vm: *VM, bytes: []const u8) !*String {
            const obj = try Obj.allocate(vm, String, .String);
            const string = obj.asString();

            string.bytes = bytes;

            // Intern string
            try vm.strings.put(bytes, string);

            return string;
        }

        pub fn destroy(self: *String, vm: *VM) void {
            vm.allocator.free(self.bytes);
            vm.allocator.destroy(self);
        }
    };
};