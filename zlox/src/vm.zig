const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./chunk.zig").OpCode;
const Value = @import("./value.zig").Value;
const printValue = @import("./value.zig").print;
const compiler = @import("./compiler.zig");
const logger = @import("./logger.zig");

const debugTraceExecution = true;

pub const InterpretResult = enum {
    Ok,
    CompileError,
    RuntimeError,
};

pub const VM = struct {
    allocator: Allocator,
    chunk: *Chunk,
    ip: usize,
    stack: ArrayList(Value),

    pub fn init(allocator: Allocator) VM {
        return VM{
            .allocator = allocator,
            .chunk = undefined,
            .ip = undefined,
            .stack = ArrayList(Value).init(allocator),
        };
    }

    pub fn deinit(self: *VM) void {
        self.stack.deinit();
    }

    pub fn interpret(self: *VM, source: []const u8) !InterpretResult {
        var chunk = Chunk.init(self.allocator);
        defer chunk.deinit();

        const success = try compiler.compile(source, &chunk);
        if (!success) return InterpretResult.CompileError;

        self.chunk = &chunk;
        self.ip = 0;

        return try self.run();
    }

    pub fn run(self: *VM) !InterpretResult {
        while (true) {
            if (debugTraceExecution) {
                self.printStack();
                _ = self.chunk.disassembleInstruction(self.ip);
            }

            if (try self.nextInstruction()) |result| return result;
        }
    }

    fn nextInstruction(self: *VM) !?InterpretResult {
        const instruction = @as(OpCode, @enumFromInt(self.readByte()));
        switch (instruction) {
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
                try self.push(.{ .Bool = valuesEqual(a, b) });
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
            .Add => return try self.binaryNumericOp(add),
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
                return InterpretResult.Ok;
            },
        }

        return null;
    }

    fn isFalsey(value: Value) bool {
        return switch (value) {
            .Bool => |b| !b,
            .Nil => true,
            else => false,
        };
    }

    fn valuesEqual(a: Value, b: Value) bool {
        if (a.isBool() and b.isBool()) {
            return a.asBool() == b.asBool();
        } else if (a.isNumber() and b.isNumber()) {
            return a.asNumber() == b.asNumber();
        } else if (a.isNil() and b.isNil()) {
            return true;
        } else {
            return false;
        }
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

    fn binaryNumericOp(self: *VM, comptime op: anytype) !?InterpretResult {
        const rhs = self.pop();
        const lhs = self.pop();

        if (lhs.isNumber() and rhs.isNumber()) {
            try self.push(.{ .Number = op(lhs.asNumber(), rhs.asNumber()) });
        } else {
            return self.runtimeError("Operands must be numbers.");
        }

        return null;
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

    fn runtimeError(self: *VM, message: []const u8) InterpretResult {
        const line = self.chunk.lines.items[self.ip];
        logger.warn("{s}", .{message});
        logger.warn("\n[line {d}] in script\n", .{line});
        self.resetStack();
        return InterpretResult.RuntimeError;
    }
};

test "vm" {
    var alloc = std.testing.allocator;
    var vm = VM.init(alloc);
    defer vm.deinit();

    try std.testing.expect(try vm.interpret("1 + 1") == .Ok);
    try std.testing.expect(try vm.interpret("1 + ") == .CompileError);
}
