const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./chunk.zig").OpCode;
const Value = @import("./value.zig").Value;
const printValue = @import("./value.zig").print;
const compiler = @import("./compiler.zig");
const logger = @import("./logger.zig");
const Obj = @import("./object.zig").Obj;

const debugTraceExecution = true;

pub const VM = struct {
    allocator: Allocator,
    chunk: *Chunk,
    ip: usize,
    stack: ArrayList(Value),
    objects: ?*Obj,
    strings: StringHashMap(*Obj.String),

    pub fn init(allocator: Allocator) VM {
        return VM{
            .allocator = allocator,
            .chunk = undefined,
            .ip = undefined,
            .stack = ArrayList(Value).init(allocator),
            .objects = null,
            .strings = StringHashMap(*Obj.String).init(allocator),
        };
    }

    pub fn deinit(self: *VM) void {
        self.stack.deinit();
        self.freeObjects();
        self.strings.deinit();
    }

    pub fn interpret(self: *VM, source: []const u8) !void {
        var chunk = Chunk.init(self.allocator);
        defer chunk.deinit();

        self.chunk = &chunk;
        self.ip = 0;

        try compiler.compile(self, source);
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
                    return self.runtimeError("Operands must be numbers.");
                }
            },
            .Less => {
                if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                    const rhs = self.pop().asNumber();
                    const lhs = self.pop().asNumber();

                    try self.push(.{ .Bool = lhs < rhs });
                } else {
                    return self.runtimeError("Operands must be numbers.");
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
                    return self.runtimeError("Operands must be numbers or strings.");
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
                    return self.runtimeError("Operand must be a number.");
                }
            },
            .Return => {
                self.pop().print();
            },
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
            return self.runtimeError("Operands must be numbers.");
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
            value.print();
            logger.debug(" ]", .{});
        }
        logger.debug("\n", .{});
    }

    fn runtimeError(self: *VM, message: []const u8) !void {
        const line = self.chunk.lines.items[self.ip];
        logger.warn("{s}", .{message});
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

test "vm" {
    var alloc = std.testing.allocator;
    var vm = VM.init(alloc);
    defer vm.deinit();

    try vm.interpret("1 + 1");
    try vm.interpret(
        \\"st" + "ri" + "ng"
    );
    try std.testing.expectError(error.CompileError, vm.interpret("1 + "));
    try std.testing.expectError(error.RuntimeError, vm.interpret("1 + true"));
}
