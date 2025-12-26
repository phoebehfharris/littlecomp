const std = @import("std");
const util = @import("util.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const SliceIter = util.SliceIter;

const ValueType = enum {
    int,
    add,
    sub,
    mul,
    div,
};

const TupleType = struct { *Value, *Value };

pub const Value = union(ValueType) { int: i32, add: TupleType, sub: TupleType, mul: TupleType, div: TupleType };

const TokenType = enum {
    num,
    lparen,
    rparen,
    div,
    mul,
    sub,
    add,
};

pub const Token = union(TokenType) {num: i32, lparen, rparen, div, mul, sub, add};

const LexerError = error{undefinedToken};
const ParserError = error{unbalancedParens};


pub fn lexExpr(allocator: Allocator, input: []const u8) ![]const Token {
    var resArr : ArrayList(Token) = .empty;
    var iter = SliceIter(u8).init(input);
    while (iter.next()) |char| {
        switch(char) {
            ' ' => {},
            '+' => try resArr.append(allocator, Token.add),
            '-' => try resArr.append(allocator, Token.sub),
            '*' => try resArr.append(allocator, Token.mul),
            '/' => try resArr.append(allocator, Token.div),
            '(' => try resArr.append(allocator, Token.lparen),
            ')' => try resArr.append(allocator, Token.rparen),
            '0'...'9' => {
                var num = char - '0';

                while (iter.peek()) |nextChar| {
                    std.debug.print("{d}\n", .{num});
                    if ('0' <= nextChar and nextChar <= '9') {
                        _ = iter.next();
                        num *= 10;
                        num += nextChar - '0';
                    } else break;
                }
                try resArr.append(allocator, Token{ .num = num });
            },
            else => return LexerError.undefinedToken,
        }
    }

    return resArr.toOwnedSlice(allocator);
}

pub fn greaterEq(token1: Token, token2: Token) bool {
    return @intFromEnum(token1) <= @intFromEnum(token2);
}

pub fn handleToken(allocator: Allocator, token: Token, outputStack: *ArrayList(Value), operatorStack: *ArrayList(Token)) !void {
    try switch(token) {
        .num => |n| outputStack.append(allocator, Value{ .int = n }),
        .lparen => operatorStack.append(allocator, token),
        .rparen => {
            while (operatorStack.pop()) |operator| {
                if (operator != Token.lparen) {
                    try createOperator(allocator, operator, outputStack);
                } else return;
            }
            return ParserError.unbalancedParens;
        },
        .div, .mul, .sub, .add => {
            while (operatorStack.getLastOrNull()) |topOperator| {
                // Top of the stack must have greater precedance. Break if token is greater or equal
                if (greaterEq(token, topOperator)) break;
                const x = operatorStack.pop();
                try createOperator(allocator, x.?, outputStack);
            }
            try operatorStack.append(allocator, token);
        }
    };
}

fn createOperator(allocator: Allocator, token: Token, outputStack: *ArrayList(Value)) !void {
    const left = outputStack.pop();
    const right = outputStack.pop();
    const val = switch(token) {
        .mul => Value{ .mul = .{
            try util.create(allocator, Value, left.?),
            try util.create(allocator, Value, right.?)
        }},
        .div => Value{ .div = .{
            try util.create(allocator, Value, left.?),
            try util.create(allocator, Value, right.?)
        }},
        .sub => Value{ .sub = .{
            try util.create(allocator, Value, left.?),
            try util.create(allocator, Value, right.?)
        }},
        .add => Value{ .add = .{
            try util.create(allocator, Value, left.?),
            try util.create(allocator, Value, right.?)
        }},
        .lparen => unreachable,
        .rparen => unreachable,
        .num => unreachable
    };
    try outputStack.append(allocator, val);
}

// We're going to try implement the shunting yard algorithm
pub fn parseExpr(allocator: Allocator, input: []const Token) !Value {
    var outputStack : ArrayList(Value) = .empty;
    var operatorStack : ArrayList(Token) = .empty;
    var sliceIter = SliceIter(Token).init(input);

    while (sliceIter.next()) |token| {
        try handleToken(allocator, token, &outputStack, &operatorStack);
    }

    while (operatorStack.pop()) |token| {
        try createOperator(allocator, token, &outputStack);
    }

    return outputStack.pop().?;
}
