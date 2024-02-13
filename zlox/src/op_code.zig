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
    Return,

    pub fn toByte(op: OpCode) u8 {
        return @intFromEnum(op);
    }

    pub fn fromByte(byte: u8) OpCode {
        return @as(OpCode, @enumFromInt(byte));
    }
};
