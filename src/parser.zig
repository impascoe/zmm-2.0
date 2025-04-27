const std = @import("std");
const tokens = @import("tokens.zig");
const ast = @import("ast.zig");

const Token = tokens.Token;

pub const Parser = struct {
    token_arr: []Token,
    position: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, _tokens: []Token) Parser {
        return Parser{ .allocator = allocator, .token_arr = _tokens, .position = 0 };
    }

    fn peek(self: *Parser) Token {
        if (self.isAtEnd()) return Token{ ._eof = {} };
        return self.tokens[self.position];
    }

    fn previous(self: *Parser) Token {
        return self.tokens[self.position - 1];
    }

    fn advance(self: *Parser) Token {
        if (!self.isAtEnd()) self.position += 1;
        return self.previous();
    }

    fn isAtEnd(self: *Parser) bool {
        return self.position >= self.tokens.len;
    }

    fn check(self: *Parser, tag: std.meta.Tag(Token)) bool {
        return std.meta.activeTag(self.peek()) == tag;
    }

    fn match(self: *Parser, token: Token) bool {
        if (self.check(token)) {
            _ = self.advance();
            return true;
        }
        return false;
    }

    fn consume(self: *Parser, token: Token, message: []const u8) void {
        if (!self.match(token)) {
            std.debug.panic("Expected token {}, got {}", .{ message, self.peek() });
        }
    }

    pub fn parse(self: *Parser) !ast.Program {
        var program = ast.Program{
            .functions = std.ArrayList(ast.Function).init(self.allocator),
        };

        while (!self.isAtEnd()) {
            try program.functions.append(try self.parseFunction());
        }

        return program;
    }

    fn parseFunction(self: *Parser) !ast.Function {
        const return_type = try self.parseType();

        // Parse function name
        const identifier = try self.parseIdentifier();

        // Parse function parameters
        try self.consume(.{ ._punctuation = ._open_parenthesis }, "Expect '(' after function name");
        const parameters = try self.parseParameters();
        try self.consume(.{ ._punctuation = ._close_parenthesis }, "Expect ')' after parameters");

        // parse body
        try self.consume(.{ ._punctuation = ._open_parenthesis }, "Expect '{' before function body");
        const body = try self.parseBlockStatement();

        return ast.Function{ .function_name = identifier, .return_type = return_type, .parameters = parameters, .function_body = body };
    }

    fn parseType(self: *Parser) !ast.Type {
        if (self.match(.{ ._keyword = ._void })) {
            return ast.Type{ .kind = .Void };
        } else if (self.match(.{ ._keyword = ._int })) {
            return ast.Type{ .kind = .Int };
        } else if (self.match(.{ ._keyword = ._char })) {
            return ast.Type{ .kind = .Char };
        } else {
            return error.InvalidType;
        }
    }

    fn parseParameters(self: *Parser) ![]ast.Parameter {
        var parameters = std.ArrayList(ast.Parameter).init(self.allocator);
        errdefer {
            for (parameters.items) |*param| {
                param.deinit(self.allocator);
            }
            parameters.deinit();
        }

        if (self.match(.{ ._punctuation = ._close_parenthesis })) {
            return parameters.toOwnedSlice();
        }

        if (self.match(.{ ._keyword = ._void })) {
            _ = self.advance();

            if (self.match(.{ ._punctuation = ._close_parenthesis })) {
                return parameters.toOwnedSlice();
            }

            self.position -= 1;
        }

        try parameters.append(try self.parseParameter());
        while (self.match(.{ ._punctuation = ._comma })) {
            _ = self.advance();
            try parameters.append(try self.parseParameter());
        }

        return parameters.toOwnedSlice();
    }

    fn parseParameter(self: *Parser) !ast.Parameter {
        const name = try self.parseIdentifier();
        _ = self.advance();
        const _type = try self.parseType();

        return ast.Parameter{ .name = name, .type = _type };
    }

    fn parseIdentifier(self: *Parser) ast.Identifier {
        if (std.meta.activeTag(self.peek()) != ._identifier) {
            return error.ExpectedIdentifier;
        }

        const token = self.advance();
        const name = try self.allocator.dupe(u8, token._identifier);
        return ast.Identifier{ .name = name };
    }

    fn parseBlockStatement(self: *Parser) !ast.Statement {
        var statements = std.ArrayList(ast.Statement).init(self.allocator);
        while (!self.check(.{ ._punctuation = ._close_brace })) {
            statements.append(try self.parseStatement());
        }
        return ast.Statement{ .compound_stmt = statements.toOwnedSlice() };
    }
};
