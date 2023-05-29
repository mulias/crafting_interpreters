const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const OpCode = enum(u8) { Return };

pub const Chunk = struct {
    code: ArrayList(u8),

    pub fn init(allocator: Allocator) Chunk {
        return Chunk{ .code = ArrayList(u8).init(allocator) };
    }

    pub fn deinit(self: *Chunk) void {
        self.code.deinit();
    }

    pub fn write(self: *Chunk, byte: u8) !void {
        try self.code.append(byte);
    }

    pub fn writeOp(self: *Chunk, op: OpCode) !void {
        try self.write(@enumToInt(op));
    }

    pub fn disassemble(self: *Chunk, name: []const u8) void {
        std.debug.print("== {s} ==\n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) {
            offset = self.disassembleInstruction(offset);
        }
    }

    pub fn disassembleInstruction(self: *Chunk, offset: usize) usize {
        std.debug.print("{:0>4} ", .{offset});

        const instruction = @intToEnum(OpCode, self.code.items[offset]);
        return switch (instruction) {
            .Return => self.simpleInstruction("OP_RETURN", offset),
        };
    }

    pub fn simpleInstruction(self: *Chunk, name: []const u8, offset: usize) usize {
        _ = self;
        std.debug.print("{s}\n", .{name});
        return offset + 1;
    }
};
