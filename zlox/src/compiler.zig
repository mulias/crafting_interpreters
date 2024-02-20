const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Obj = @import("./object.zig").Obj;
const Parser = @import("./parser.zig").Parser;
const Scanner = @import("./scanner.zig").Scanner;
const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;
const VM = @import("./vm.zig").VM;
const logger = @import("./logger.zig");

pub const Compiler = struct {
    vm: *VM,
    locals: ArrayList(Local),
    scopeDepth: usize,
    function: *Obj.Function,

    pub fn init(vm: *VM) Compiler {
        return Compiler{
            .vm = vm,
            .locals = ArrayList(Local).init(vm.allocator),
            .scopeDepth = 0,
            .function = undefined,
        };
    }

    pub fn deinit(self: *Compiler) void {
        self.locals.deinit();
    }

    pub fn compile(self: *Compiler, source: []const u8) !*Obj.Function {
        // Stack slot 0 is reserved by the VM for the main function. This means
        // we can't store a local in this position. Create a placeholder local
        // which is never referenced so that locals on the stack are offset by
        // 1.
        try self.locals.append(Local{
            .depth = 0,
            .name = undefined,
            .initialized = true,
        });

        // Implicit main function for the script as a whole.
        self.function = try Obj.Function.create(self.vm, .Script);

        var parser = Parser.init(self, source);

        parser.advance();

        while (!parser.match(TokenType.Eof)) {
            try parser.declaration();
        }

        parser.consume(TokenType.Eof, "Expect end of expression.");

        try parser.end();

        if (parser.hadError) return error.CompileError;

        return self.function;
    }

    pub fn incScope(self: *Compiler) void {
        self.scopeDepth += 1;
    }

    pub fn decScope(self: *Compiler) void {
        self.scopeDepth -= 1;
    }

    pub fn isGlobalScope(self: *Compiler) bool {
        return self.scopeDepth == 0;
    }

    pub fn addLocal(self: *Compiler, name: Token) !void {
        for (self.locals.items) |local| {
            if (local.initialized and local.depth < self.scopeDepth) {
                break;
            }

            if (identifiersEqual(name, local.name)) {
                return error.VariableNameUsedInScope;
            }
        }

        try self.locals.append(Local{
            .name = name,
            .depth = self.scopeDepth,
            .initialized = false,
        });
    }

    pub fn resolveLocal(self: *Compiler, name: Token) !?usize {
        var i = self.locals.items.len;
        while (i > 0) {
            i -= 1;

            const local = self.locals.items[i];

            if (identifiersEqual(name, local.name)) {
                if (local.initialized) {
                    return i;
                } else {
                    return error.NotYetInitialized;
                }
            }
        }

        return null;
    }

    fn identifiersEqual(a: Token, b: Token) bool {
        return std.mem.eql(u8, a.lexeme, b.lexeme);
    }
};

pub const Local = struct {
    name: Token,
    depth: usize,
    initialized: bool,

    pub fn markInitialized(self: *Local) void {
        self.initialized = true;
    }
};
