const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        if (gpa.deinit() == .leak) {
            std.log.err("Memory leak", .{});
        }
    }

    if (args.len < 2) {
        std.debug.print("Usage: zmm [filename]\n", .{});
        return;
    }

    const file_path = args[1];
    var tokenizer = try Tokenizer.init(allocator, file_path);
    defer tokenizer.deinit();

    const tokens = try tokenizer.tokenize();
    defer {
        for (tokens) |token| {
            token.deinit(allocator);
        }
        allocator.free(tokens);
    }

    std.debug.print("Found {} tokens:\n", .{tokens.len});
    for (tokens, 0..) |token, i| {
        std.debug.print("Token {}: ", .{i});
        switch (token) {
            ._keyword => |keyword| std.debug.print("Keyword: {}\n", .{keyword}),
            ._punctuation => |punct| std.debug.print("Punctuation: {}\n", .{punct}),
            ._constant => |constant| {
                std.debug.print("Constant: ", .{});
                switch (constant.kind) {
                    .int_val => std.debug.print("Int({})\n", .{constant.value.int_val}),
                    .float_val => std.debug.print("Float({})\n", .{constant.value.float_val}),
                    .char_val => std.debug.print("Char('{c}')\n", .{constant.value.char_val}),
                    .string_val => std.debug.print("String(\"{s}\")\n", .{constant.value.string_val}),
                }
            },
            ._identifier => |id| std.debug.print("Identifier: \"{s}\"\n", .{id}),
        }
    }
}
