const std = @import("std");

const Keyword = enum {
    _int,
    _void,
    _char,
    _return,
};

const Punctuation = enum {
    _open_parenthesis,
    _close_parenthesis,
    _open_brace,
    _close_brace,
    _semicolon,
};

const Constant = struct { kind: enum { int_val, float_val, char_val, string_val }, value: union {
    int_val: i32,
    float_val: f32,
    char_val: u8,
    string_val: []const u8,
} };

const Token = union(enum) {
    _keyword: Keyword,
    _punctuation: Punctuation,
    _constant: Constant,
    _identifier: []const u8,
};

const Program = struct {
    functions: []Function,
};

const Function = struct {
    function_name: []const u8,
    function_body: Statement,
};

const Statement = union(enum) {
    return_stmt: Return,
    expression_stmt: Expression,
};

const Expression = union(enum) {
    constant_expr: Constant,
    // identifier: Identifier,
    // operation: Operation,
};

const Return = struct {
    return_value: Expression, // for now, only constants are supported
};

const Parser = struct {
    tokens: []Token,
    current_token: usize,
    allocator: std.mem.Allocator,

    pub fn init(tokens: []Token, allocator: std.mem.Allocator) Parser {
        return Parser{ .tokens = tokens, .current_token = 0, .allocator = allocator };
    }

    fn peek(self: *Parser) ?Token {
        if (self.current_token + 1 >= self.tokens.len) return null;
        return self.tokens[self.current_token];
    }

    fn consume(self: *Parser) Token {
        return self.tokens[self.current_token + 1];
    }

    fn match(self: *Parser, tag: Token) bool {
        if (self.peek()) |token| {
            if (std.meta.activeTag(token) == tag) {
                self.current_token += 1;
                return true;
            }
        }
        return false;
    }
};

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

    const file = std.fs.cwd().openFile(args[1], .{}) catch |err| {
        std.log.err("Failed to open file: {s}", .{@errorName(err)});
        return;
    };

    defer file.close();
    var buffer = std.ArrayList(u8).init(allocator);
    var tokens = std.ArrayList(Token).init(allocator);
    defer buffer.deinit();
    defer tokens.deinit();

    while (file.reader().readUntilDelimiterOrEofAlloc(allocator, '\n', 1024) catch |err| {
        std.log.err("Failed to read line: {s}", .{@errorName(err)});
        return;
    }) |line| {
        defer allocator.free(line);
        var index: usize = 0;
        std.debug.print("{s}\n", .{line});
        while (index < line.len) {
            const cur_char = line[index];
            if (std.ascii.isAlphabetic(cur_char)) { // if it is a keyword or identifier then go ahead
                try buffer.append(cur_char);
                index += 1;
                while (index < line.len and std.ascii.isAlphanumeric(line[index])) { // gets the entire 'word'
                    try buffer.append(line[index]);
                    index += 1;
                }
                index -= 1;
                // detecting what kind of token it is
                // std.debug.print("{s}", .{buffer.items});
                if (std.mem.eql(u8, buffer.items, "int")) {
                    try tokens.append(Token{ ._keyword = Keyword._int });
                    buffer.clearRetainingCapacity();
                } else if (std.mem.eql(u8, buffer.items, "void")) {
                    try tokens.append(Token{ ._keyword = Keyword._void });
                    buffer.clearRetainingCapacity();
                } else if (std.mem.eql(u8, buffer.items, "return")) {
                    try tokens.append(Token{ ._keyword = Keyword._return });
                    buffer.clearRetainingCapacity();
                } else { // if not a keyword, then it is a identifier

                    index += 1;
                    // std.debug.print("\n", .{});
                    // std.debug.print("{s}\n", .{buffer.items});
                    while (index < line.len and (std.ascii.isAlphanumeric(line[index]) or line[index] == '_')) { // gets the entire 'word'
                        try buffer.append(line[index]);
                        index += 1;
                    }
                    index -= 1;
                    const identifier = try allocator.dupe(u8, buffer.items);

                    try tokens.append(Token{ ._identifier = identifier });
                    buffer.clearRetainingCapacity();
                }
                buffer.clearRetainingCapacity();
            } else if (std.ascii.isWhitespace(cur_char)) {} else if (std.ascii.isDigit(cur_char)) {
                var temp_int = cur_char - '0';
                while (std.ascii.isDigit(line[index + 1])) {
                    temp_int *= 10;
                    temp_int += (line[index + 1] - '0');
                    index += 1;
                }
                try tokens.append(Token{ ._constant = Constant{ .kind = .int_val, .value = .{ .int_val = temp_int } } });
                buffer.clearRetainingCapacity();
            } else if (cur_char == ';') {
                try tokens.append(Token{ ._punctuation = Punctuation._semicolon });
                buffer.clearRetainingCapacity();
            } else if (cur_char == '(') {
                try tokens.append(Token{ ._punctuation = Punctuation._open_parenthesis });
                buffer.clearRetainingCapacity();
            } else if (cur_char == ')') {
                try tokens.append(Token{ ._punctuation = Punctuation._close_parenthesis });
                buffer.clearRetainingCapacity();
            } else if (cur_char == '{') {
                try tokens.append(Token{ ._punctuation = Punctuation._open_brace });
                buffer.clearRetainingCapacity();
            } else if (cur_char == '}') {
                try tokens.append(Token{ ._punctuation = Punctuation._close_brace });
                buffer.clearRetainingCapacity();
            } else {
                std.log.err("Invalid token {s}", .{buffer.items});
            }
            index += 1;
        }
    }

    while (tokens.items.len > 0) {
        const token = tokens.orderedRemove(0);
        // std.debug.print("{any}\n", .{token});

        switch (token) {
            ._constant => {
                std.debug.print("Constant: {any}\n", .{token._constant});
            },
            ._identifier => {
                std.debug.print("Identifier: {s}\n", .{token._identifier});
                allocator.free(token._identifier);
            },
            ._keyword => {
                std.debug.print("Identifier: {any}\n", .{token._keyword});
            },
            ._punctuation => {
                std.debug.print("Punctuation: {any}\n", .{token._punctuation});
            },
        }
    }
}
