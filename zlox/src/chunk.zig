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

    pub fn get(self: *Chunk, offset: usize) u8 {
        return self.code.items[offset];
    }

    pub fn getOp(self: *Chunk, offset: usize) OpCode {
        return OpCode.fromByte(self.get(offset));
    }

    pub fn getShort(self: *Chunk, offset: usize) u16 {
        return (@as(u16, @intCast(self.code.items[offset])) << 8) | self.code.items[offset + 1];
    }

    pub fn write(self: *Chunk, byte: u8, line: u32) !void {
        try self.code.append(byte);
        try self.lines.append(line);
    }

    pub fn writeOp(self: *Chunk, op: OpCode, line: u32) !void {
        try self.write(op.toByte(), line);
    }

    pub fn writeShort(self: *Chunk, value: u16, line: u32) !void {
        try self.write(@as(u8, @intCast((value >> 8) & 0xff)), line);
        try self.write(@as(u8, @intCast(value & 0xff)), line);
    }

    pub fn update(self: *Chunk, idx: usize, value: u8) void {
        self.code.items[idx] = value;
    }

    pub fn updateShort(self: *Chunk, idx: usize, value: u16) void {
        self.update(idx, @as(u8, @intCast((value >> 8) & 0xff)));
        self.update(idx + 1, @as(u8, @intCast(value & 0xff)));
    }

    pub fn addConstant(self: *Chunk, value: Value) !u9 {
        const idx = @as(u9, @intCast(self.constants.items.len));
        try self.constants.append(value);
        return idx;
    }

    pub fn byteCount(self: *Chunk) usize {
        return self.code.items.len;
    }

    pub fn disassemble(self: *Chunk, name: []const u8) void {
        logger.debug("== {s} ==\n", .{name});

        var offset: usize = 0;
        while (offset < self.byteCount()) {
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
        return instruction.disassemble(self, offset);
    }
};
