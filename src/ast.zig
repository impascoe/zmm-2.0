const std = @import("std");
const tokens = @import("tokens.zig");

const Program = struct {
    functions: std.ArrayList(Function),
};

const Function = struct {
    function_name: Identifier,
    return_type: Type,
    function_body: []Statement,

    // pub fn deinit(self: *Function, allocator: std.mem.Allocator) void {
    //     allocator.free(self.name);
    //     for (self.parameters) |param| {
    //         allocator.free(param.name);
    //         // If Type has any heap allocations, free those too
    //     }
    //     // Free the parameters array itself
    //     allocator.free(self.parameters);

    //     // Recursively free the function body
    //     self.body.deinit(allocator);
    // }
};

const Parameter = struct {
    name: []const u8,
    type: Type,
};

const Identifier = struct {
    name: []const u8,

    pub fn deinit(self: *Identifier, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

const Type = struct {
    kind: TypeKind,
    // todo pointer stuff

};

const TypeKind = enum {
    Void,
    Int,
    Char,
    Float,
    Double,
};

const Statement = union(enum) {
    return_stmt: Return,
    expression_stmt: Expression,
    compound_stmt: []Statement,
};

const Expression = union(enum) {
    constant_expr: tokens.Constant,
    // identifier: Identifier,
    // operation: Operation,
};

const Return = struct {
    return_value: Expression, // for now, only constants are supported
};
