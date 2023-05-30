const std = @import("std");
const OpCode = @import("./chunk.zig").OpCode;
const Chunk = @import("./chunk.zig").Chunk;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    var constantIdx = try chunk.addConstant(1.2);
    try chunk.writeOp(OpCode.Constant, 123);
    try chunk.write(constantIdx, 123);

    try chunk.writeOp(OpCode.Return, 123);

    chunk.disassemble("test chunk");

    return;
}
