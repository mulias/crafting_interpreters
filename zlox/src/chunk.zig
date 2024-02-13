const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const OpCode = @import("./op_code.zig").OpCode;
const Value = @import("./value.zig").Value;
const logger = @import("./logger.zig");

pub const Chunk = struct {
    code: ArrayList(u8),
    constants: ArrayList(Value),
    lines: ArrayList(u32),

    pub fn init(allocator: Allocator) Chunk {
        return Chunk{
            .code = ArrayList(u8).init(allocator),
            .constants = ArrayList(Value).init(allocator),
            .lines = ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *Chunk) void {
        self.code.deinit();
        self.constants.deinit();
        self.lines.deinit();
    }

    pub fn write(self: *Chunk, byte: u8, line: u32) !void {
        try self.code.append(byte);
        try self.lines.append(line);
    }

    pub fn writeOp(self: *Chunk, op: OpCode, line: u32) !void {
        try self.write(op.toByte(), line);
    }

    pub fn addConstant(self: *Chunk, value: Value) !u9 {
        const idx = @as(u9, @intCast(self.constants.items.len));
        try self.constants.append(value);
        return idx;
    }

    pub fn disassemble(self: *Chunk, name: []const u8) void {
        logger.debug("== {s} ==\n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) {
            offset = self.disassembleInstruction(offset);
        }
    }

    pub fn disassembleInstruction(self: *Chunk, offset: usize) usize {
        // print address
        logger.debug("{:0>4} ", .{offset});

        // print line
        if (offset > 0 and self.lines.items[offset] == self.lines.items[offset - 1]) {
            logger.debug("   | ", .{});
        } else {
            logger.debug("{: >4} ", .{self.lines.items[offset]});
        }

        const instruction = OpCode.fromByte(self.code.items[offset]);
        return switch (instruction) {
            .Constant,
            .GetGlobal,
            .DefineGlobal,
            .SetGlobal,
            => self.constantInstruction(instruction, offset),
            .GetLocal,
            .SetLocal,
            => self.byteInstruciton(instruction, offset),
            .True,
            .False,
            .Pop,
            .Equal,
            .Greater,
            .Less,
            .Nil,
            .Add,
            .Subtract,
            .Multiply,
            .Divide,
            .Not,
            .Negate,
            .Print,
            .Return,
            => self.simpleInstruction(instruction, offset),
        };
    }

    fn simpleInstruction(self: *Chunk, instruction: OpCode, offset: usize) usize {
        _ = self;
        logger.debug("{s}\n", .{@tagName(instruction)});
        return offset + 1;
    }

    fn constantInstruction(self: *Chunk, instruction: OpCode, offset: usize) usize {
        var constantIdx = self.code.items[offset + 1];
        var constantValue = self.constants.items[constantIdx];
        logger.debug("{s} {} '", .{ @tagName(instruction), constantIdx });
        constantValue.print(logger.debug);
        logger.debug("'\n", .{});
        return offset + 2;
    }

    fn byteInstruciton(self: *Chunk, instruction: OpCode, offset: usize) usize {
        const slot = self.code.items[offset + 1];
        logger.debug("{s} {d}\n", .{ @tagName(instruction), slot });
        return offset + 2;
    }
};
