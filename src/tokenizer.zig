const std = @import("std");
const tokens = @import("tokens.zig");

const Token = tokens.Token;
const Keyword = tokens.Keyword;
const Constant = tokens.Constant;

pub const Tokenizer = struct {
    position: usize,
    allocator: std.mem.Allocator,
    content: []const u8,

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

        return Tokenizer{ .position = 0, .allocator = allocator, .content = content };
    }

    fn peek(self: *Tokenizer) ?u8 {
        if (self.position >= self.content.len) return null;
        return self.content[self.position];
    }

    fn consume(self: *Tokenizer) ?u8 {
        if (self.position >= self.content.len) return null;
        const char = self.content[self.position];
        self.position += 1;
        return char;
    }

    pub fn deinit(self: *Tokenizer) void {
        self.allocator.free(self.content);
    }

    pub fn tokenize(self: *Tokenizer) ![]Token {
        var buffer = std.ArrayList(u8).init(self.allocator);
        var token_list = std.ArrayList(Token).init(self.allocator);

        defer buffer.deinit();

        while (self.peek() != null) {
            if (std.ascii.isAlphabetic(self.peek().?)) {
                try buffer.append(self.consume().?);
                while (self.peek() != null and std.ascii.isAlphanumeric(self.peek().?)) {
                    try buffer.append(self.consume().?);
                }
                if (std.mem.eql(u8, buffer.items, "int")) {
                    try token_list.append(Token{ ._keyword = Keyword._int });
                    buffer.clearRetainingCapacity();
                    // add other keywords here
                } else {
                    while (self.peek() != null and (std.ascii.isAlphanumeric(self.peek().?) or self.peek() == '_')) {
                        try buffer.append(self.consume().?);
                    }
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
                std.log.err("Invalid token {s}", .{buffer.items});
            }
        }
        self.position = 0;
        try token_list.append(Token{ ._eof = {} });
        return token_list.toOwnedSlice();
    }
};
