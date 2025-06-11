const std = @import("std");

pub const Keyword = enum {
    _int,
    _void,
    _char,
    _return,
};

pub const Punctuation = enum {
    _open_parenthesis,
    _close_parenthesis,
    _open_brace,
    _close_brace,
    _semicolon,
    _comma,
};

pub const Constant = struct { kind: enum { int_val, float_val, char_val, string_val }, value: union {
    int_val: i32,
    float_val: f32,
    char_val: u8,
    string_val: []const u8,
} };

pub const Token = union(enum) {
    _keyword: Keyword,
    _punctuation: Punctuation,
    _constant: Constant,
    _identifier: []const u8,
    _eof: void,

    pub fn deinit(self: Token, allocator: std.mem.Allocator) void {
        switch (self) {
            ._identifier => |id| {
                // Only free if it's a valid slice
                if (id.len > 0) {
                    allocator.free(id);
                }
            },
            ._constant => {
                switch (self._constant.kind) {
                    .int_val, .float_val, .char_val => {},
                    .string_val => {
                        // Only free string values if they're valid
                        const str = self._constant.value.string_val;
                        if (str.len > 0) {
                            allocator.free(str);
                        }
                    },
                }
            },
            ._eof, ._keyword, ._punctuation => {}, // These don't contain heap allocations
        }
    }
};
