const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Chunk = @import("./chunk.zig").Chunk;
const Compiler = @import("./compiler.zig").Compiler;
const Obj = @import("./object.zig").Obj;
const OpCode = @import("./op_code.zig").OpCode;
const StringHashMap = std.StringHashMap;
const Value = @import("./value.zig").Value;
const logger = @import("./logger.zig");
const printValue = @import("./value.zig").print;

const debugTraceExecution = true;

pub const VM = struct {
    allocator: Allocator,
    chunk: *Chunk,
    ip: usize,
    stack: ArrayList(Value),
    objects: ?*Obj,
    globals: AutoHashMap(*Obj.String, Value),
    strings: StringHashMap(*Obj.String),

    pub fn init(allocator: Allocator) VM {
        return VM{
            .allocator = allocator,
            .chunk = undefined,
            .ip = undefined,
            .stack = ArrayList(Value).init(allocator),
            .objects = null,
            .globals = AutoHashMap(*Obj.String, Value).init(allocator),
            .strings = StringHashMap(*Obj.String).init(allocator),
        };
    }

    pub fn deinit(self: *VM) void {
        self.stack.deinit();
        self.freeObjects();
        self.globals.deinit();
        self.strings.deinit();
    }

    pub fn interpret(self: *VM, source: []const u8) !void {
        var chunk = Chunk.init(self.allocator);
        defer chunk.deinit();

        var compiler = Compiler.init(self);
        defer compiler.deinit();

        self.chunk = &chunk;
        self.ip = 0;

        try compiler.compile(source);
        try self.run();
    }

    pub fn run(self: *VM) !void {
        while (true) {
            if (debugTraceExecution) {
                self.printStack();
                _ = self.chunk.disassembleInstruction(self.ip);
            }

            const opCode = @as(OpCode, @enumFromInt(self.readByte()));
            try self.runOp(opCode);
            if (opCode == .Return and self.stack.items.len == 0) break;
        }
    }

    fn runOp(self: *VM, opCode: OpCode) !void {
        switch (opCode) {
            .Constant => {
                const constantIdx = self.readByte();
                const value = self.chunk.constants.items[constantIdx];
                try self.push(value);
            },
            .True => try self.push(.{ .Bool = true }),
            .False => try self.push(.{ .Bool = false }),
            .Pop => {
                _ = self.pop();
            },
            .GetLocal => {
                const slot = self.readByte();
                try self.push(self.stack.items[slot]);
            },
            .SetLocal => {
                const slot = self.readByte();
                self.stack.items[slot] = self.peek(0);
            },
            .GetGlobal => {
                const nameIdx = self.readByte();
                const name = self.chunk.constants.items[nameIdx].asObj().asString();
                if (self.globals.get(name)) |value| {
                    try self.push(value);
                } else {
                    return self.runtimeError("Undefined variable '{s}'.", .{name.bytes});
                }
            },
            .DefineGlobal => {
                const nameIdx = self.readByte();
                const name = self.chunk.constants.items[nameIdx].asObj().asString();
                try self.globals.put(name, self.peek(0));
                _ = self.pop();
            },
            .SetGlobal => {
                const nameIdx = self.readByte();
                const name = self.chunk.constants.items[nameIdx].asObj().asString();
                const oldValue = try self.globals.fetchPut(name, self.peek(0));
                const notDefined = oldValue == null;

                if (notDefined) {
                    return self.runtimeError("Undefined variable '{s}'.", .{name.bytes});
                }
            },
            .Equal => {
                const b = self.pop();
                const a = self.pop();
                try self.push(.{ .Bool = a.isEql(b) });
            },
            .Greater => {
                if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                    const rhs = self.pop().asNumber();
                    const lhs = self.pop().asNumber();

                    try self.push(.{ .Bool = lhs > rhs });
                } else {
                    return self.runtimeError("Operands must be numbers.", .{});
                }
            },
            .Less => {
                if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                    const rhs = self.pop().asNumber();
                    const lhs = self.pop().asNumber();

                    try self.push(.{ .Bool = lhs < rhs });
                } else {
                    return self.runtimeError("Operands must be numbers.", .{});
                }
            },
            .Nil => try self.push(.{ .Nil = undefined }),
            .Add => {
                const rhs = self.pop();
                const lhs = self.pop();

                if (lhs.isNumber() and rhs.isNumber()) {
                    try self.push(.{ .Number = lhs.asNumber() + rhs.asNumber() });
                } else if (rhs.isObj() and lhs.isObj() and rhs.asObj().isString() and lhs.asObj().isString()) {
                    try self.concatenate(lhs.asObj().asString(), rhs.asObj().asString());
                } else {
                    return self.runtimeError("Operands must be numbers or strings.", .{});
                }
            },
            .Subtract => return try self.binaryNumericOp(sub),
            .Multiply => return try self.binaryNumericOp(mul),
            .Divide => return try self.binaryNumericOp(div),
            .Not => try self.push(.{ .Bool = isFalsey(self.pop()) }),
            .Negate => {
                if (self.peek(0).isNumber()) {
                    const n = self.pop().asNumber();
                    try self.push(.{ .Number = -n });
                } else {
                    return self.runtimeError("Operand must be a number.", .{});
                }
            },
            .Print => {
                self.pop().print(logger.info);
                logger.info("\n", .{});
            },
            .Return => {},
        }
    }

    fn isFalsey(value: Value) bool {
        return switch (value) {
            .Bool => |b| !b,
            .Nil => true,
            else => false,
        };
    }

    fn add(x: f64, y: f64) f64 {
        return x + y;
    }

    fn sub(x: f64, y: f64) f64 {
        return x - y;
    }

    fn mul(x: f64, y: f64) f64 {
        return x * y;
    }

    fn div(x: f64, y: f64) f64 {
        return x / y;
    }

    fn binaryNumericOp(self: *VM, comptime op: anytype) !void {
        const rhs = self.pop();
        const lhs = self.pop();

        if (lhs.isNumber() and rhs.isNumber()) {
            try self.push(.{ .Number = op(lhs.asNumber(), rhs.asNumber()) });
        } else {
            return self.runtimeError("Operands must be numbers.", .{});
        }
    }

    fn concatenate(self: *VM, lhs: *Obj.String, rhs: *Obj.String) !void {
        const buffer = try self.allocator.alloc(u8, lhs.bytes.len + rhs.bytes.len);
        std.mem.copy(u8, buffer[0..lhs.bytes.len], lhs.bytes);
        std.mem.copy(u8, buffer[lhs.bytes.len..], rhs.bytes);

        const string = try Obj.String.create(self, buffer);
        try self.push(string.obj.value());
    }

    fn readByte(self: *VM) u8 {
        const byte = self.chunk.code.items[self.ip];
        self.ip += 1;
        return byte;
    }

    fn push(self: *VM, value: Value) !void {
        try self.stack.append(value);
    }

    fn pop(self: *VM) Value {
        return self.stack.pop();
    }

    fn peek(self: *VM, distance: usize) Value {
        var len = self.stack.items.len;
        return self.stack.items[len - 1 - distance];
    }

    fn resetStack(self: *VM) void {
        self.stack.shrinkAndFree(0);
    }

    fn printStack(self: *VM) void {
        logger.debug("          ", .{});
        for (self.stack.items) |value| {
            logger.debug("[ ", .{});
            value.print(logger.debug);
            logger.debug(" ]", .{});
        }
        logger.debug("\n", .{});
    }

    fn runtimeError(self: *VM, comptime message: []const u8, args: anytype) !void {
        const line = self.chunk.lines.items[self.ip];
        logger.warn(message, args);
        logger.warn("\n[line {d}] in script\n", .{line});
        self.resetStack();
        return error.RuntimeError;
    }

    fn freeObjects(self: *VM) void {
        var object = self.objects;
        while (object) |o| {
            var next = o.next;
            o.destroy(self);
            object = next;
        }
    }
};

test "number expression" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret("1 + 1;");
}

test "print expression" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\print "st" + "ri" + "ng";
        \\print 1 + 3;
    );
}

test "global vars" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\var breakfast = "beignets";
        \\var beverage = "cafe au lait";
        \\breakfast = "beignets with " + beverage;
        \\
        \\print breakfast;
    );
}

test "local vars" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\{
        \\  var a = 1;
        \\  {
        \\    var b = 2;
        \\    {
        \\      var c = 3;
        \\      {
        \\        var d = 4;
        \\      }
        \\      var e = 5;
        \\    }
        \\    var f = 6;
        \\    {
        \\      var g = 7;
        \\    }
        \\  }
        \\}
    );
}

test "print local vars" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\{
        \\  var y = 2;
        \\  print y;
        \\}
    );
}

test "global and local vars" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\var x = 1;
        \\{
        \\  var y = x + 1;
        \\  print y;
        \\}
        \\x = 2;
        \\print x;
    );
}

test "compiler errors" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectError(error.CompileError, vm.interpret("1 + "));
    try std.testing.expectError(error.CompileError, vm.interpret("a * b = c + d;"));
}

test "runtime errors" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectError(error.RuntimeError, vm.interpret("1 + true;"));
    try std.testing.expectError(error.RuntimeError, vm.interpret(
        \\foo = 1;
    ));
}
