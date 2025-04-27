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
            ._identifier => allocator.free(self._identifier),
            ._constant => {
                switch (self._constant.kind) {
                    .int_val => {},
                    .float_val => {},
                    .char_val => {},
                    .string_val => allocator.free(self._constant.value.string_val),
                }
            },
            ._eof => {},
            else => {},
        }
    }
};
