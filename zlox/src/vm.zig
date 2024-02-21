const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Chunk = @import("./chunk.zig").Chunk;
const Obj = @import("./object.zig").Obj;
const OpCode = @import("./op_code.zig").OpCode;
const StringHashMap = std.StringHashMap;
const Value = @import("./value.zig").Value;
const compile = @import("./compiler.zig").compile;
const logger = @import("./logger.zig");
const printValue = @import("./value.zig").print;

const debugTraceExecution = true;

const CallFrame = struct {
    function: *Obj.Function,
    ip: usize,
    stackOffset: usize,
};

pub const VM = struct {
    allocator: Allocator,
    stack: ArrayList(Value),
    frames: ArrayList(CallFrame),
    objects: ?*Obj,
    globals: AutoHashMap(*Obj.String, Value),
    strings: StringHashMap(*Obj.String),

    pub fn init(allocator: Allocator) VM {
        return VM{
            .allocator = allocator,
            .stack = ArrayList(Value).init(allocator),
            .frames = ArrayList(CallFrame).init(allocator),
            .objects = null,
            .globals = AutoHashMap(*Obj.String, Value).init(allocator),
            .strings = StringHashMap(*Obj.String).init(allocator),
        };
    }

    pub fn deinit(self: *VM) void {
        self.stack.deinit();
        self.frames.deinit();
        self.freeObjects();
        self.globals.deinit();
        self.strings.deinit();
    }

    pub fn interpret(self: *VM, source: []const u8) !void {
        const function = try compile(self, source);
        try self.push(function.obj.value());
        try self.addFrame(function);

        try self.run();
    }

    pub fn run(self: *VM) !void {
        while (true) {
            if (debugTraceExecution) {
                self.printStack();
                _ = self.chunk().disassembleInstruction(self.frame().ip);
            }

            const opCode = self.readOp();
            try self.runOp(opCode);
            if (opCode == .Return and self.stack.items.len == 1) break;
        }
    }

    fn runOp(self: *VM, opCode: OpCode) !void {
        switch (opCode) {
            .Constant => {
                const id = self.readByte();
                const value = self.getConstant(id);
                try self.push(value);
            },
            .True => try self.push(.{ .Bool = true }),
            .False => try self.push(.{ .Bool = false }),
            .Pop => {
                _ = self.pop();
            },
            .GetLocal => {
                const slot = self.readByte();
                try self.push(self.getLocal(slot));
            },
            .SetLocal => {
                const slot = self.readByte();
                self.setLocal(slot, self.peek(0));
            },
            .GetGlobal => {
                const id = self.readByte();
                const name = self.getConstant(id).asObj().asString();
                if (self.globals.get(name)) |value| {
                    try self.push(value);
                } else {
                    return self.runtimeError("Undefined variable '{s}'.", .{name.bytes});
                }
            },
            .DefineGlobal => {
                const id = self.readByte();
                const name = self.getConstant(id).asObj().asString();
                try self.globals.put(name, self.peek(0));
                _ = self.pop();
            },
            .SetGlobal => {
                const id = self.readByte();
                const name = self.getConstant(id).asObj().asString();
                const oldValue = try self.globals.fetchPut(name, self.peek(0));
                const notDefined = oldValue == null;

                if (notDefined) {
                    return self.runtimeError("Undefined variable '{s}'.", .{name.bytes});
                }
            },
            .Equal => {
                const b = self.pop();
                const a = self.pop();
                try self.push(.{ .Bool = a.isEql(b) });
            },
            .Greater => {
                if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                    const rhs = self.pop().asNumber();
                    const lhs = self.pop().asNumber();

                    try self.push(.{ .Bool = lhs > rhs });
                } else {
                    return self.runtimeError("Operands must be numbers.", .{});
                }
            },
            .Less => {
                if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                    const rhs = self.pop().asNumber();
                    const lhs = self.pop().asNumber();

                    try self.push(.{ .Bool = lhs < rhs });
                } else {
                    return self.runtimeError("Operands must be numbers.", .{});
                }
            },
            .Nil => try self.push(.{ .Nil = undefined }),
            .Add => {
                const rhs = self.pop();
                const lhs = self.pop();

                if (lhs.isNumber() and rhs.isNumber()) {
                    try self.push(.{ .Number = lhs.asNumber() + rhs.asNumber() });
                } else if (rhs.isObj() and lhs.isObj() and rhs.asObj().isString() and lhs.asObj().isString()) {
                    try self.concatenate(lhs.asObj().asString(), rhs.asObj().asString());
                } else {
                    return self.runtimeError("Operands must be numbers or strings.", .{});
                }
            },
            .Subtract => return try self.binaryNumericOp(sub),
            .Multiply => return try self.binaryNumericOp(mul),
            .Divide => return try self.binaryNumericOp(div),
            .Not => try self.push(.{ .Bool = self.pop().isFalsey() }),
            .Negate => {
                if (self.peek(0).isNumber()) {
                    const n = self.pop().asNumber();
                    try self.push(.{ .Number = -n });
                } else {
                    return self.runtimeError("Operand must be a number.", .{});
                }
            },
            .Print => {
                self.pop().print(logger.info);
                logger.info("\n", .{});
            },
            .Jump => {
                const offset = self.readShort();
                self.frame().ip += offset;
            },
            .JumpIfFalse => {
                const offset = self.readShort();
                if (self.peek(0).isFalsey()) self.frame().ip += offset;
            },
            .Loop => {
                const offset = self.readShort();
                self.frame().ip -= offset;
            },
            .Call => {
                const argCount = self.readByte();
                try self.callValue(self.peek(argCount), argCount);
            },
            .Return => {
                const result = self.pop();
                const prevFrame = self.frames.pop();
                if (self.frames.items.len == 0) return;

                try self.stack.resize(prevFrame.stackOffset);

                try self.push(result);
            },
        }
    }

    fn frame(self: *VM) *CallFrame {
        return &self.frames.items[self.frames.items.len - 1];
    }

    fn chunk(self: *VM) *Chunk {
        return &self.frame().function.chunk;
    }

    pub fn getConstant(self: *VM, id: usize) Value {
        return self.chunk().constants.items[id];
    }

    pub fn getLocal(self: *VM, slot: usize) Value {
        return self.stack.items[self.frame().stackOffset + slot];
    }

    pub fn setLocal(self: *VM, slot: usize, value: Value) void {
        self.stack.items[self.frame().stackOffset + slot] = value;
    }

    fn addFrame(self: *VM, function: *Obj.Function) !void {
        try self.frames.append(CallFrame{
            .function = function,
            .ip = 0,
            .stackOffset = self.stack.items.len - function.arity - 1,
        });
    }

    fn sub(x: f64, y: f64) f64 {
        return x - y;
    }

    fn mul(x: f64, y: f64) f64 {
        return x * y;
    }

    fn div(x: f64, y: f64) f64 {
        return x / y;
    }

    fn binaryNumericOp(self: *VM, comptime op: anytype) !void {
        const rhs = self.pop();
        const lhs = self.pop();

        if (lhs.isNumber() and rhs.isNumber()) {
            try self.push(.{ .Number = op(lhs.asNumber(), rhs.asNumber()) });
        } else {
            return self.runtimeError("Operands must be numbers.", .{});
        }
    }

    fn concatenate(self: *VM, lhs: *Obj.String, rhs: *Obj.String) !void {
        const buffer = try self.allocator.alloc(u8, lhs.bytes.len + rhs.bytes.len);
        std.mem.copy(u8, buffer[0..lhs.bytes.len], lhs.bytes);
        std.mem.copy(u8, buffer[lhs.bytes.len..], rhs.bytes);

        const string = try Obj.String.create(self, buffer);
        try self.push(string.obj.value());
    }

    fn callValue(self: *VM, value: Value, argCount: u8) !void {
        if (value.isObj() and value.asObj().isFunction()) {
            const fun = value.asObj().asFunction();

            if (fun.arity == argCount) {
                try self.addFrame(fun);
            } else {
                return self.runtimeError("Expected {} arguments but got {}.", .{ fun.arity, argCount });
            }
        } else {
            return self.runtimeError("Can only call functions and classes.", .{});
        }
    }

    fn readByte(self: *VM) u8 {
        const byte = self.chunk().get(self.frame().ip);
        self.frame().ip += 1;
        return byte;
    }

    fn readOp(self: *VM) OpCode {
        const op = self.chunk().getOp(self.frame().ip);
        self.frame().ip += 1;
        return op;
    }

    fn readShort(self: *VM) u16 {
        const short = self.chunk().getShort(self.frame().ip);
        self.frame().ip += 2;
        return short;
    }

    fn push(self: *VM, value: Value) !void {
        try self.stack.append(value);
    }

    fn pop(self: *VM) Value {
        return self.stack.pop();
    }

    fn peek(self: *VM, distance: usize) Value {
        var len = self.stack.items.len;
        return self.stack.items[len - 1 - distance];
    }

    fn resetStack(self: *VM) void {
        self.stack.shrinkAndFree(0);
    }

    fn printStack(self: *VM) void {
        logger.debug("          ", .{});
        for (self.stack.items) |value| {
            logger.debug("[ ", .{});
            value.print(logger.debug);
            logger.debug(" ]", .{});
        }
        logger.debug("\n", .{});
    }

    fn runtimeError(self: *VM, comptime message: []const u8, args: anytype) !void {
        const line = self.chunk().lines.items[self.frame().ip];
        logger.warn(message, args);
        logger.warn("\n[line {d}] in script\n", .{line});
        self.resetStack();
        return error.RuntimeError;
    }

    fn freeObjects(self: *VM) void {
        var object = self.objects;
        while (object) |o| {
            var next = o.next;
            o.destroy(self);
            object = next;
        }
    }
};

test "number expression" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret("1 + 1;");
}

test "print expression" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\print "st" + "ri" + "ng";
        \\print 1 + 3;
    );
}

test "global vars" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\var breakfast = "beignets";
        \\var beverage = "cafe au lait";
        \\breakfast = "beignets with " + beverage;
        \\
        \\print breakfast;
    );
}

test "local vars" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\{
        \\  var a = 1;
        \\  {
        \\    var b = 2;
        \\    {
        \\      var c = 3;
        \\      {
        \\        var d = 4;
        \\      }
        \\      var e = 5;
        \\    }
        \\    var f = 6;
        \\    {
        \\      var g = 7;
        \\    }
        \\  }
        \\}
    );
}

test "print local vars" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\{
        \\  var y = 2;
        \\  print y;
        \\}
    );
}

test "global and local vars" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\var x = 1;
        \\{
        \\  var y = x + 1;
        \\  print y;
        \\}
        \\x = 2;
        \\print x;
    );
}

test "if when true" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\if (true) print 1;
        \\print 2;
    );
}

test "if when false" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\if (false) print 1;
        \\print 2;
    );
}

test "if/else when true" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\var x = 1;
        \\if (x == 1) {
        \\  print 1;
        \\} else {
        \\  print 2;
        \\}
    );
}

test "if/else when false" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\var x = 1;
        \\if (x == 2) {
        \\  print 1;
        \\} else {
        \\  print 2;
        \\}
    );
}

test "and" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\var a = true and true;
        \\var b = true and false;
        \\var c = false and true;
        \\var d = false and false;
        \\print a;
        \\print b;
        \\print c;
        \\print d;
    );
}

test "or" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\var a = true or true;
        \\var b = true or false;
        \\var c = false or true;
        \\var d = false or false;
        \\print a;
        \\print b;
        \\print c;
        \\print d;
    );
}

test "while" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\var i = 5;
        \\while (i > 0) {
        \\  print i;
        \\  i = i - 1;
        \\}
        \\print "done";
    );
}

test "for loop" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\for (var i = 0; i < 10; i = i + 1) {
        \\  print i;
        \\}
        \\print "done";
    );
}

test "print function as variable" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\fun areWeHavingItYet() {
        \\  print "Yes we are!";
        \\}
        \\
        \\print areWeHavingItYet;
    );
}

test "call function" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try vm.interpret(
        \\fun sum(a, b, c) {
        \\  return a + b + c;
        \\}
        \\
        \\print 4 + sum(5, 6, 7);
    );
}

test "compiler errors" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectError(error.CompileError, vm.interpret("1 + "));
    try std.testing.expectError(error.CompileError, vm.interpret("a * b = c + d;"));
}

test "runtime errors" {
    var vm = VM.init(std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectError(error.RuntimeError, vm.interpret("1 + true;"));
    try std.testing.expectError(error.RuntimeError, vm.interpret(
        \\foo = 1;
    ));
}
