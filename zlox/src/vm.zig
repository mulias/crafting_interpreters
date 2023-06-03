const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./chunk.zig").OpCode;
const Value = @import("./value.zig").Value;
const printValue = @import("./value.zig").print;
const compiler = @import("./compiler.zig");

const debugTraceExecution = true;

pub const InterpretResult = enum {
    Ok,
    CompileError,
    RuntimeError,
};

pub const VM = struct {
    chunk: *Chunk,
    ip: usize,
    stack: ArrayList(Value),

    pub fn init(allocator: Allocator) VM {
        return VM{
            .chunk = undefined,
            .ip = undefined,
            .stack = ArrayList(Value).init(allocator),
        };
    }

    pub fn deinit(self: *VM) void {
        self.stack.deinit();
    }

    pub fn interpret(self: *VM, source: []const u8) !InterpretResult {
        _ = self;
        compiler.compile(source);
        return InterpretResult.Ok;
    }

    pub fn run(self: *VM) !InterpretResult {
        while (true) {
            if (debugTraceExecution) {
                self.printStack();
                _ = self.chunk.disassembleInstruction(self.ip);
            }

            const instruction = @intToEnum(OpCode, self.readByte());
            switch (instruction) {
                .Constant => {
                    const constantIdx = self.readByte();
                    const value = self.chunk.constants.items[constantIdx];
                    try self.push(value);
                },
                .Add => {
                    const rhs = self.pop();
                    const lhs = self.pop();
                    try self.push(lhs + rhs);
                },
                .Subtract => {
                    const rhs = self.pop();
                    const lhs = self.pop();
                    try self.push(lhs - rhs);
                },
                .Multiply => {
                    const rhs = self.pop();
                    const lhs = self.pop();
                    try self.push(lhs * rhs);
                },
                .Divide => {
                    const rhs = self.pop();
                    const lhs = self.pop();
                    try self.push(lhs / rhs);
                },
                .Negate => try self.push(-self.pop()),
                .Return => {
                    printValue(self.pop());
                    std.debug.print("\n", .{});
                    return InterpretResult.Ok;
                },
            }
        }
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

    fn printStack(self: *VM) void {
        std.debug.print("          ", .{});
        for (self.stack.items) |value| {
            std.debug.print("[ {d} ]", .{value});
        }
        std.debug.print("\n", .{});
    }
};
