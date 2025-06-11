const std = @import("std");

const tokens = @import("tokens.zig");

pub const Program = struct {
    functions: std.ArrayList(Function),

    pub fn deinit(self: *Program, allocator: std.mem.Allocator) void {
        for (self.functions.items) |*func| {
            func.deinit(allocator);
        }
        self.functions.deinit();
    }
};

pub const Function = struct {
    function_name: Identifier,
    return_type: Type,
    parameters: []Parameter,
    function_body: []Statement,
    pub fn deinit(self: *Function, allocator: std.mem.Allocator) void {
        self.function_name.deinit(allocator);
        for (self.parameters) |*param| {
            param.deinit(allocator);
        }
        allocator.free(self.parameters);
        for (self.function_body) |*stmt| {
            stmt.deinit(allocator);
        }
        allocator.free(self.function_body);
    }
};

pub const Parameter = struct {
    name: Identifier,
    type: Type,

    pub fn deinit(self: *Parameter, allocator: std.mem.Allocator) void {
        self.name.deinit(allocator);
    }
};

pub const Identifier = struct {
    name: []const u8,

    pub fn deinit(self: *Identifier, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

pub const Type = struct {
    kind: TypeKind,
    // todo pointer stuff

};

pub const TypeKind = enum {
    Void,
    Int,
    Char,
    Float,
    Double,
};

pub const Statement = union(enum) {
    return_stmt: Return,
    expression_stmt: Expression,
    compound_stmt: []Statement,
    pub fn deinit(self: *Statement, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .compound_stmt => |stmts| {
                for (stmts) |*stmt| {
                    stmt.deinit(allocator);
                }
                allocator.free(stmts);
            },
            .return_stmt => |*ret| {
                ret.deinit(allocator);
            },
            .expression_stmt => |*expr| {
                expr.deinit(allocator);
            },
        }
    }
};

pub const Expression = union(enum) {
    constant_expr: tokens.Constant,
    // identifier: Identifier,
    // operation: Operation,
    pub fn deinit(self: *Expression, allocator: std.mem.Allocator) void {
        // No heap allocations yet
        _ = allocator;
        std.debug.print("{any}", .{self});
    }
};

pub const Return = struct {
    return_value: ?Expression, // for now, only constants are supported
    pub fn deinit(self: *Return, allocator: std.mem.Allocator) void {
        if (self.return_value) |*expr| {
            expr.deinit(allocator);
        }
    }
};
