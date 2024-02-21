const std = @import("std");
const Chunk = @import("./chunk.zig").Chunk;
const VM = @import("./vm.zig").VM;
const Value = @import("./value.zig").Value;

pub const Obj = struct {
    objType: Type,
    next: ?*Obj,

    pub const Type = enum {
        String,
        Function,
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
            .Function => self.asFunction().destroy(vm),
        }
    }

    pub fn value(self: *Obj) Value {
        return Value{ .Obj = self };
    }

    pub fn print(self: *Obj, printer: anytype) void {
        switch (self.objType) {
            .String => printer("{s}", .{self.asString().bytes}),
            .Function => printer("<fn {s}>", .{self.asFunction().getName()}),
        }
    }

    pub fn isEql(a: *Obj, b: *Obj) bool {
        if (a.isType(.String) and b.isType(.String)) {
            // Strings are interned so they can be compared by address
            return a == b;
        } else {
            return false;
        }
    }

    pub fn isType(self: *Obj, objType: Type) bool {
        return self.objType == objType;
    }

    pub fn asString(self: *Obj) *String {
        return @fieldParentPtr(String, "obj", self);
    }

    pub fn asFunction(self: *Obj) *Function {
        return @fieldParentPtr(Function, "obj", self);
    }

    pub const String = struct {
        obj: Obj,
        bytes: []const u8,

        pub fn copy(vm: *VM, source: []const u8) !*String {
            const buffer = try vm.allocator.alloc(u8, source.len);
            std.mem.copy(u8, buffer, source);
            return String.create(vm, buffer);
        }

        pub fn create(vm: *VM, bytes: []const u8) !*String {
            if (vm.strings.get(bytes)) |interned| {
                vm.allocator.free(bytes);
                return interned;
            } else {
                const obj = try Obj.allocate(vm, String, .String);
                const string = obj.asString();

                string.bytes = bytes;

                // Intern string
                try vm.strings.put(bytes, string);

                return string;
            }
        }

        pub fn destroy(self: *String, vm: *VM) void {
            vm.allocator.free(self.bytes);
            vm.allocator.destroy(self);
        }
    };

    pub const FunctionType = enum { NamedFunction, Script };

    pub const Function = struct {
        obj: Obj,
        arity: u8,
        chunk: Chunk,
        name: ?*String,
        functionType: FunctionType,

        pub fn create(vm: *VM, functionType: FunctionType, name: ?*String) !*Function {
            const obj = try Obj.allocate(vm, Function, .Function);
            const fun = obj.asFunction();
            fun.* = Function{
                .obj = obj.*,
                .arity = 0,
                .chunk = Chunk.init(vm.allocator),
                .name = name,
                .functionType = functionType,
            };

            return fun;
        }

        pub fn destroy(self: *Function, vm: *VM) void {
            // The `name` string is owned by the VM and might live beyond the
            // function.
            self.chunk.deinit();
            vm.allocator.destroy(self);
        }

        pub fn isScript(self: *Function) bool {
            return self.functionType == .Script;
        }

        pub fn getName(self: *Function) []const u8 {
            if (self.isScript()) {
                return "script";
            } else if (self.name) |name| {
                return name.bytes;
            } else {
                unreachable;
            }
        }
    };
};
