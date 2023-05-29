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
    try chunk.writeOp(OpCode.Constant);
    try chunk.write(constantIdx);

    try chunk.writeOp(OpCode.Return);

    chunk.disassemble("test chunk");

    return;
}
