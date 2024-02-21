const Chunk = @import("./chunk.zig").Chunk;
const logger = @import("./logger.zig");

pub const OpCode = enum(u8) {
    Constant,
    Nil,
    True,
    False,
    Pop,
    GetLocal,
    SetLocal,
    GetGlobal,
    DefineGlobal,
    SetGlobal,
    Equal,
    Greater,
    Less,
    Add,
    Subtract,
    Multiply,
    Divide,
    Not,
    Negate,
    Print,
    Jump,
    JumpIfFalse,
    Loop,
    Call,
    Return,

    pub fn toByte(op: OpCode) u8 {
        return @intFromEnum(op);
    }

    pub fn fromByte(byte: u8) OpCode {
        return @as(OpCode, @enumFromInt(byte));
    }

    pub fn disassemble(op: OpCode, chunk: *Chunk, offset: usize) usize {
        return switch (op) {
            .Constant,
            .GetGlobal,
            .DefineGlobal,
            .SetGlobal,
            => op.constantInstruction(chunk, offset),
            .GetLocal,
            .SetLocal,
            .Call,
            => op.byteInstruciton(chunk, offset),
            .Jump,
            .JumpIfFalse,
            => op.jumpInstruction(chunk, 1, offset),
            .Loop => op.jumpInstruction(chunk, -1, offset),
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
            => op.simpleInstruction(offset),
        };
    }

    fn simpleInstruction(op: OpCode, offset: usize) usize {
        logger.debug("{s}\n", .{@tagName(op)});
        return offset + 1;
    }

    fn constantInstruction(op: OpCode, chunk: *Chunk, offset: usize) usize {
        var constantIdx = chunk.get(offset + 1);
        var constantValue = chunk.constants.items[constantIdx];
        logger.debug("{s} {} '", .{ @tagName(op), constantIdx });
        constantValue.print(logger.debug);
        logger.debug("'\n", .{});
        return offset + 2;
    }

    fn byteInstruciton(op: OpCode, chunk: *Chunk, offset: usize) usize {
        const slot = chunk.get(offset + 1);
        logger.debug("{s} {d}\n", .{ @tagName(op), slot });
        return offset + 2;
    }

    fn jumpInstruction(op: OpCode, chunk: *Chunk, sign: isize, offset: usize) usize {
        const jump = chunk.getShort(offset + 1);
        const target = @as(isize, @intCast(offset)) + 3 + sign * jump;
        logger.debug("{s} {d} -> {d}\n", .{ @tagName(op), offset, target });
        return offset + 3;
    }
};
