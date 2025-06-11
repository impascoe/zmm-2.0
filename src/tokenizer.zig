const std = @import("std");

const tokens = @import("tokens.zig");
const Token = tokens.Token;
const Keyword = tokens.Keyword;
const Constant = tokens.Constant;

pub const Tokenizer = struct {
    position: usize,
    allocator: std.mem.Allocator,
    content: []const u8,
    line: usize,
    column: usize,

    pub fn init(allocator: std.mem.Allocator, file_path: []const u8) !Tokenizer {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const content = try allocator.alloc(u8, file_size);

        const bytes_read = try file.readAll(content);
        if (bytes_read != file_size) {
            allocator.free(content);
            return error.IncompleteRead;
        }

        return Tokenizer{ .position = 0, .allocator = allocator, .content = content, .line = 1, .column = 1 };
    }

    fn peek(self: *Tokenizer) ?u8 {
        if (self.position >= self.content.len) return null;
        return self.content[self.position];
    }

    fn consume(self: *Tokenizer) ?u8 {
        if (self.position >= self.content.len) return null;
        const char = self.content[self.position];
        self.position += 1;

        // Track line and column
        if (char == '\n') {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }

        return char;
    }

    pub fn deinit(self: *Tokenizer) void {
        self.allocator.free(self.content);
    }

    // Add this function to the Tokenizer struct
    pub fn reportError(self: *Tokenizer) void {
        // Calculate line and column if you're tracking them
        // Otherwise just report position
        const peeked_char = self.peek();
        if (peeked_char == null) {
            std.debug.print("Invalid token character: <null> at line {}, column {}\n", .{ self.line, self.column });
        } else {
            std.debug.print("Invalid token character: '{c}' at line {}, column {}\n", .{ peeked_char.?, self.line, self.column });
        }
    }

    pub fn tokenize(self: *Tokenizer) ![]Token {
        var buffer = std.ArrayList(u8).init(self.allocator);
        var token_list = std.ArrayList(Token).init(self.allocator);

        defer buffer.deinit();
        errdefer {
            // Clean up any tokens we've already created
            for (token_list.items) |*token| {
                token.deinit(self.allocator);
            }
            token_list.deinit();
        }

        while (self.peek() != null) {
            if (std.ascii.isAlphabetic(self.peek().?)) {
                try buffer.append(self.consume().?);
                while (self.peek() != null and std.ascii.isAlphanumeric(self.peek().?)) {
                    try buffer.append(self.consume().?);
                }
                if (std.mem.eql(u8, buffer.items, "int")) {
                    try token_list.append(Token{ ._keyword = Keyword._int });
                    buffer.clearRetainingCapacity();
                } else if (std.mem.eql(u8, buffer.items, "return")) {
                    try token_list.append(Token{ ._keyword = Keyword._return });
                    buffer.clearRetainingCapacity();
                } else if (std.mem.eql(u8, buffer.items, "void")) {
                    try token_list.append(Token{ ._keyword = Keyword._void });
                    buffer.clearRetainingCapacity();
                } else if (std.mem.eql(u8, buffer.items, "char")) {
                    try token_list.append(Token{ ._keyword = Keyword._char });
                    buffer.clearRetainingCapacity();
                } else {
                    // Here was the bug: we were trying to consume more characters after
                    // already reading the full identifier in the previous loop
                    const identifier = try self.allocator.dupe(u8, buffer.items);
                    try token_list.append(Token{ ._identifier = identifier });
                    buffer.clearRetainingCapacity();
                }
            } else if (std.ascii.isWhitespace(self.peek().?)) {
                _ = self.consume().?;
            } else if (std.ascii.isDigit(self.peek().?)) {
                var temp_int = self.consume().? - '0';
                while (std.ascii.isDigit(self.peek().?)) {
                    temp_int *= 10;
                    temp_int += (self.consume().? - '0');
                }
                try token_list.append(Token{ ._constant = Constant{ .kind = .int_val, .value = .{ .int_val = temp_int } } });
                buffer.clearRetainingCapacity();
            } else if (self.peek() == ';') {
                try token_list.append(Token{ ._punctuation = ._semicolon });
                _ = self.consume();
                buffer.clearRetainingCapacity();
            } else if (self.peek() == ',') {
                try token_list.append(Token{ ._punctuation = ._comma });
                _ = self.consume();
                buffer.clearRetainingCapacity();
            } else if (self.peek() == '(') {
                try token_list.append(Token{ ._punctuation = ._open_parenthesis });
                _ = self.consume();
                buffer.clearRetainingCapacity();
            } else if (self.peek() == ')') {
                try token_list.append(Token{ ._punctuation = ._close_parenthesis });
                _ = self.consume();
                buffer.clearRetainingCapacity();
            } else if (self.peek() == '{') {
                try token_list.append(Token{ ._punctuation = ._open_brace });
                _ = self.consume();
                buffer.clearRetainingCapacity();
            } else if (self.peek() == '}') {
                try token_list.append(Token{ ._punctuation = ._close_brace });
                _ = self.consume();
                buffer.clearRetainingCapacity();
            } else {
                // For invalid tokens, log an error and stop
                self.reportError();
                return error.InvalidToken;
            }
        }
        self.position = 0;
        try token_list.append(Token{ ._eof = {} });
        return token_list.toOwnedSlice();
    }
};
