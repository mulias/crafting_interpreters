const std = @import("std");
const OpCode = @import("./chunk.zig").OpCode;
const Chunk = @import("./chunk.zig").Chunk;
const VM = @import("./vm.zig").VM;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var vm = VM.init(allocator);
    defer vm.deinit();

    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    var constantIdx = try chunk.addConstant(1.2);
    try chunk.writeOp(OpCode.Constant, 123);
    try chunk.write(constantIdx, 123);

    constantIdx = try chunk.addConstant(3.4);
    try chunk.writeOp(OpCode.Constant, 123);
    try chunk.write(constantIdx, 123);

    try chunk.writeOp(OpCode.Add, 123);

    constantIdx = try chunk.addConstant(5.6);
    try chunk.writeOp(OpCode.Constant, 123);
    try chunk.write(constantIdx, 123);

    try chunk.writeOp(OpCode.Divide, 123);

    try chunk.writeOp(OpCode.Negate, 123);

    try chunk.writeOp(OpCode.Return, 123);

    chunk.disassemble("test chunk");

    std.debug.print("\n== run vm ==\n", .{});
    _ = try vm.interpret(&chunk);

    return;
}
