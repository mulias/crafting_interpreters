const std = @import("std");
const OpCode = @import("./chunk.zig").OpCode;
const Chunk = @import("./chunk.zig").Chunk;
const VM = @import("./vm.zig").VM;
const Allocator = std.mem.Allocator;
const logger = @import("./logger.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    switch (args.len) {
        1 => try repl(allocator),
        2 => try runFile(allocator, args[1]),
        else => {
            logger.info("Usage: zlox [path]\n", .{});
            std.process.exit(64);
        },
    }

    return;
}

fn repl(allocator: Allocator) !void {
    const stdin = std.io.getStdIn().reader();
    var buffer: [256]u8 = undefined;

    var vm = VM.init(allocator);
    defer vm.deinit();

    while (true) {
        logger.info("> ", .{});
        if (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |source| {
            vm.interpret(source) catch |err| switch (err) {
                error.CompileError, error.RuntimeError => {},
                error.OutOfMemory => return err,
            };
            logger.info("\n", .{});
        }
    }
}

fn runFile(allocator: Allocator, path: []const u8) !void {
    var vm = VM.init(allocator);
    defer vm.deinit();

    const source = try std.fs.cwd().readFileAlloc(allocator, path, 1e10);
    defer allocator.free(source);

    vm.interpret(source) catch |err| switch (err) {
        error.CompileError => std.process.exit(65),
        error.RuntimeError => std.process.exit(70),
        error.OutOfMemory => return err,
    };
}

test {
    @import("std").testing.refAllDecls(@This());
}
