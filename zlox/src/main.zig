const std = @import("std");
const OpCode = @import("./chunk.zig").OpCode;
const Chunk = @import("./chunk.zig").Chunk;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    try chunk.writeOp(OpCode.Return);

    chunk.disassemble("test chunk");

    return;
}
