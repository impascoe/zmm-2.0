const std = @import("std");

const Parser = @import("parser.zig").Parser;
const Tokenizer = @import("tokenizer.zig").Tokenizer;

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);
    var gpa = std.heap.DebugAllocator(.{}).init;
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

    var compilation_succeeded = true;

    var tokenizer = Tokenizer.init(allocator, file_path) catch |err| {
        std.debug.print("Error opening file: {}\n", .{err});
        // Return success (not error) so the build succeeds
        compilation_succeeded = false;
        std.process.exit(1);
        return;
    };

    defer tokenizer.deinit();

    const tokens = tokenizer.tokenize() catch |err| {
        // Handle tokenization errors
        std.debug.print("Tokenization error: {}\n", .{err});
        // Return success (not error) so the build succeeds
        compilation_succeeded = false;
        std.process.exit(1);
        return;
    };

    // We'll free tokens at the end
    defer {
        // Safely free the tokens
        for (tokens) |*token| {
            token.deinit(allocator);
        }
        allocator.free(tokens);
    }

    var parser = Parser.init(allocator, tokens) catch |err| {
        std.debug.print("Parser initialization error: {}\n", .{err});
        compilation_succeeded = false;
        std.process.exit(1);
        return;
    };

    var program = parser.parse() catch |err| {
        std.debug.print("Parsing error: {}\n", .{err});
        compilation_succeeded = false;
        std.process.exit(1);
        return;
    };

    std.debug.print("{any}", .{program});

    // Free the program after we're done with it
    defer program.deinit(allocator);

    // Exit with appropriate code if compilation failed
    if (!compilation_succeeded) {
        std.process.exit(1);
    }
}
