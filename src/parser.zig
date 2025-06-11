const std = @import("std");

const ast = @import("ast.zig");
const tokens = @import("tokens.zig");
const Token = tokens.Token;

pub const Parser = struct {
    token_arr: []Token,
    position: usize,
    allocator: std.mem.Allocator,
    had_error: bool, // Tracks if an error has been encountered
    error_message: []const u8, // Stores the latest error message
    error_position: usize, // Stores the token position where the error occurred

    pub fn init(allocator: std.mem.Allocator, _tokens: []Token) !Parser {
        return Parser{
            .allocator = allocator,
            .token_arr = _tokens,
            .position = 0,
            .had_error = false,
            .error_message = "",
            .error_position = 0,
        };
    }

    fn peek(self: *Parser) Token {
        if (self.isAtEnd()) return Token{ ._eof = {} };
        return self.token_arr[self.position];
    }

    fn previous(self: *Parser) Token {
        return self.token_arr[self.position - 1];
    }

    fn advance(self: *Parser) Token {
        if (!self.isAtEnd()) self.position += 1;
        return self.previous();
    }

    fn isAtEnd(self: *Parser) bool {
        return self.position >= self.token_arr.len;
    }

    fn check(self: *Parser, expected_token: Token) bool {
        // Compare active tag first (e.g., _keyword vs _identifier)
        const current_token = self.peek();
        if (std.meta.activeTag(current_token) != std.meta.activeTag(expected_token)) {
            return false;
        }

        // For tagged unions, we need to compare the actual values inside
        switch (expected_token) {
            ._keyword => |expected_keyword| {
                if (current_token._keyword != expected_keyword) {
                    return false;
                }
            },
            ._punctuation => |expected_punct| {
                if (current_token._punctuation != expected_punct) {
                    return false;
                }
            },
            else => {}, // Other types like identifiers and constants we don't compare values
        }

        // If we get here, the token matched
        return true;
    }

    fn compare(self: *Parser, token: Token) bool {
        if (self.check(token)) {
            return true;
        }
        return false;
    }

    fn match(self: *Parser, expected_token: Token) bool {
        // Compare active tag first (e.g., _keyword vs _identifier)
        const current_token = self.peek();
        if (std.meta.activeTag(current_token) != std.meta.activeTag(expected_token)) {
            return false;
        }

        // For tagged unions, we need to compare the actual values inside
        switch (expected_token) {
            ._keyword => |expected_keyword| {
                if (current_token._keyword != expected_keyword) {
                    return false;
                }
            },
            ._punctuation => |expected_punct| {
                if (current_token._punctuation != expected_punct) {
                    return false;
                }
            },
            else => {}, // Other types like identifiers and constants we don't compare values
        }

        // If we get here, the token matched
        _ = self.advance();
        return true;
    }

    fn consume(self: *Parser, expected_token: Token, message: []const u8) !void {
        if (self.had_error) return error.ParsingFailed;

        if (self.match(expected_token)) {
            return; // Successfully consumed the token
        }

        // If we got here, the expected token wasn't found
        self.reportError(message);
        return error.ExpectedToken;
    }

    pub fn reportError(self: *Parser, message: []const u8) void {
        if (!self.had_error) {
            self.had_error = true;
            self.error_message = message;
            self.error_position = self.position;

            std.debug.print("Error at token {}: {s}", .{ self.position, message });
            if (self.position < self.token_arr.len) {
                std.debug.print("Near: {any}", .{self.token_arr[self.position]});
            }
        }
    }

    pub fn parse(self: *Parser) !ast.Program {
        var program = ast.Program{
            .functions = std.ArrayList(ast.Function).init(self.allocator),
        };
        errdefer program.deinit(self.allocator);

        while (!self.isAtEnd()) {
            // Stop parsing if we've encountered an error
            if (self.had_error) {
                break;
            }

            // Skip actual EOF tokens
            if (std.meta.activeTag(self.peek()) == ._eof) {
                break;
            }

            const result = self.parseFunction() catch |err| {
                // Handle the error, then break out of the loop
                std.debug.print("Error parsing function: {}", .{err});
                break;
            };

            try program.functions.append(result);
        }

        // If we had an error, return it
        if (self.had_error) {
            return error.ParsingFailed;
        }

        return program;
    }

    fn parseFunction(self: *Parser) !ast.Function {
        if (self.had_error) return error.ParsingFailed;
        std.log.debug("Starting parseFunction. Current token: {any}", .{self.peek()});
        const return_type = try self.parseType();
        std.log.debug("After parseType. Current token: {any}", .{self.peek()});

        // Parse function name
        const identifier = try self.parseIdentifier();
        std.log.debug("After parseIdentifier. Current token: {any}", .{self.peek()});
        // Parse function parameters
        std.log.debug("{any}", .{self.peek()});
        try self.consume(.{ ._punctuation = ._open_parenthesis }, "Expected '(' after function name");
        std.log.debug("{any}", .{self.peek()});
        const parameters = try self.parseParameters();
        std.log.debug("{any}", .{self.peek()});
        try self.consume(.{ ._punctuation = ._close_parenthesis }, "Expected ')' after parameters");
        std.log.debug("{any}", .{self.peek()});
        // parse body
        try self.consume(.{ ._punctuation = ._open_brace }, "Expected '{' before function body");
        std.log.debug("{any}", .{self.peek()});
        const body_statement = try self.parseBlockStatement();
        const body = switch (body_statement) {
            .compound_stmt => |stmts| stmts,
            else => return error.ExpectedCompoundStatement,
        };

        return ast.Function{ .function_name = identifier, .return_type = return_type, .parameters = parameters, .function_body = body };
    }

    fn parseType(self: *Parser) !ast.Type {
        if (self.had_error) return error.ParsingFailed;
        std.log.debug("Start parseType. Current token: {any}", .{self.peek()});
        if (self.match(.{ ._keyword = ._void })) {
            std.log.debug("Found void type", .{});
            return ast.Type{ .kind = .Void };
        } else if (self.match(.{ ._keyword = ._int })) {
            std.log.debug("Found int type", .{});
            return ast.Type{ .kind = .Int };
        } else if (self.match(.{ ._keyword = ._char })) {
            std.log.debug("Found char type", .{});
            return ast.Type{ .kind = .Char };
        } else {
            std.log.debug(" error: {any}", .{self.peek()});
            return error.InvalidType;
        }
    }

    fn parseParameters(self: *Parser) ![]ast.Parameter {
        if (self.had_error) return error.ParsingFailed;
        std.log.debug("Starting parseParameters. Current token: {any}", .{self.peek()});
        var parameters = std.ArrayList(ast.Parameter).init(self.allocator);
        errdefer {
            for (parameters.items) |*param| {
                param.deinit(self.allocator);
            }
            parameters.deinit();
        }

        // Handle empty parameter list
        if (self.check(.{ ._punctuation = ._close_parenthesis })) {
            return try parameters.toOwnedSlice();
        }

        // Handle "void" as the only parameter
        if (self.match(.{ ._keyword = ._void })) {
            if (self.check(.{ ._punctuation = ._close_parenthesis })) {
                return try parameters.toOwnedSlice();
            }
            // Not a void parameter, rewind (though this shouldn't happen in valid C)
            self.position -= 1;
        }

        // Parse first parameter
        try parameters.append(try self.parseParameter());

        // Parse additional parameters (x, y, z, ...)
        while (self.match(.{ ._punctuation = ._comma })) {
            try parameters.append(try self.parseParameter());
        }

        return try parameters.toOwnedSlice();
    }

    fn parseParameter(self: *Parser) !ast.Parameter {
        if (self.had_error) return error.ParsingFailed;
        const _type = try self.parseType();
        // std.debug.print("{any}", .{self.peek()});
        const name = try self.parseIdentifier();
        // std.debug.print("{any}", .{self.peek()});
        return ast.Parameter{ .name = name, .type = _type };
    }

    fn parseIdentifier(self: *Parser) !ast.Identifier {
        if (self.had_error) return error.ParsingFailed;
        if (std.meta.activeTag(self.peek()) != ._identifier) {
            std.debug.print("Error: Expected identifier but got {any}", .{self.peek()});
            return error.ExpectedIdentifier;
        }

        const token = self.advance();
        const name = try self.allocator.dupe(u8, token._identifier);
        return ast.Identifier{ .name = name };
    }

    fn parseBlockStatement(self: *Parser) !ast.Statement {
        if (self.had_error) return error.ParsingFailed;
        var statements = std.ArrayList(ast.Statement).init(self.allocator);
        errdefer statements.deinit();
        while (!self.match(.{ ._punctuation = ._close_brace })) {
            try statements.append(try self.parseStatement());
        }
        return ast.Statement{ .compound_stmt = try statements.toOwnedSlice() };
    }

    fn parseStatement(self: *Parser) !ast.Statement {
        if (self.had_error) return error.ParsingFailed;
        std.log.debug("parseStatement: current token: {any}", .{self.peek()});
        if (self.match(.{ ._keyword = ._return })) {
            return ast.Statement{ .return_stmt = try self.parseReturnStatement() };
        } else {
            // Handle multi-token statements or expressions with error recovery
            // Just consume tokens until we see a semicolon or block end
            var found_semicolon = false;
            while (!self.isAtEnd() and !found_semicolon) {
                if (self.match(.{ ._punctuation = ._semicolon })) {
                    found_semicolon = true;
                    break;
                } else if (self.check(.{ ._punctuation = ._close_brace })) {
                    // Reached the end of a block without finding a semicolon
                    break;
                } else {
                    // Skip over the current token
                    std.debug.print("Skipping token in error recovery: {any}", .{self.peek()});
                    _ = self.advance();
                }
            }

            // Return a placeholder expression
            return ast.Statement{ .expression_stmt = .{ .constant_expr = .{ .kind = .int_val, .value = .{ .int_val = 0 } } } };
        }
    }

    fn parseReturnStatement(self: *Parser) !ast.Return {
        if (self.had_error) return error.ParsingFailed;
        std.log.debug("Starting parseReturnStatement. Current token: {any}", .{self.peek()});

        // Check for 'return;' (without a value)
        if (self.check(.{ ._punctuation = ._semicolon })) {
            _ = self.advance(); // Consume the semicolon
            return ast.Return{ .return_value = null };
        }

        // Otherwise, expect an expression
        const expression = try self.parseExpression();
        try self.consume(.{ ._punctuation = ._semicolon }, "Expected ';' after return statement");
        return ast.Return{ .return_value = expression };
    }

    fn parseExpression(self: *Parser) !ast.Expression {
        if (self.had_error) return error.ParsingFailed;
        std.log.debug("Starting parseExpression. Current token: {any}", .{self.peek()});

        // Handle constants
        if (std.meta.activeTag(self.peek()) == ._constant) {
            const token = self.advance();
            return ast.Expression{ .constant_expr = token._constant };
        }
        // Handle identifiers
        else if (std.meta.activeTag(self.peek()) == ._identifier) {
            _ = self.advance(); // Just advance the tokenizer without using the token
            // Create a special constant for now - in a real parser you'd create a variable reference
            return ast.Expression{ .constant_expr = .{ .kind = .int_val, .value = .{ .int_val = 0 } } };
        } else {
            std.log.debug("Unknown expression type: {any}", .{self.peek()});
            return error.UnexpectedToken;
        }
    }
};
