const std = @import("std");
const Allocator = std.mem.Allocator;
const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./chunk.zig").OpCode;
const printValue = @import("./value.zig").print;

const debugTraceExecution = true;

pub const InterpretResult = enum {
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR,
};

pub const VM = struct {
    chunk: *Chunk,
    ip: usize,

    pub fn init() VM {
        return VM{
            .chunk = undefined,
            .ip = undefined,
        };
    }

    pub fn deinit(self: *VM) void {
        _ = self;
    }

    pub fn interpret(self: *VM, chunk: *Chunk) InterpretResult {
        self.chunk = chunk;
        self.ip = 0;
        return self.run();
    }

    pub fn run(self: *VM) InterpretResult {
        while (true) {
            if (debugTraceExecution) {
                _ = self.chunk.disassembleInstruction(self.ip);
            }

            const instruction = @intToEnum(OpCode, self.readByte());
            switch (instruction) {
                .Return => {
                    return InterpretResult.OK;
                },
                .Constant => {
                    const constantIdx = self.readByte();
                    const value = self.chunk.constants.items[constantIdx];
                    printValue(value);
                    std.debug.print("\n", .{});
                },
            }
        }
    }

    fn readByte(self: *VM) u8 {
        const byte = self.chunk.code.items[self.ip];
        self.ip += 1;
        return byte;
    }
};
