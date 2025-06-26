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

const TupleType = struct { Value, Value };

pub const Value = union(ValueType) { int: i32, add: *TupleType, sub: *TupleType, mul: *TupleType, div: *TupleType };

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
    var resArr = ArrayList(Token).init(allocator);
    var iter = SliceIter(u8).init(input);
    while (iter.next()) |char| {
        switch(char) {
            ' ' => {},
            '+' => try resArr.append(Token.add),
            '-' => try resArr.append(Token.sub),
            '*' => try resArr.append(Token.mul),
            '/' => try resArr.append(Token.div),
            '(' => try resArr.append(Token.lparen),
            ')' => try resArr.append(Token.rparen),
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
                try resArr.append(Token{ .num = num });
            },
            else => return LexerError.undefinedToken,
        }
    }

    return resArr.toOwnedSlice();
}

pub fn greaterEq(token1: Token, token2: Token) bool {
    return @intFromEnum(token1) <= @intFromEnum(token2);
}

pub fn handleToken(allocator: Allocator, token: Token, outputStack: *ArrayList(Value), operatorStack: *ArrayList(Token)) !void {
    try switch(token) {
        .num => |n| outputStack.append(Value{ .int = n }),
        .lparen => operatorStack.append(token),
        .rparen => {
            while (operatorStack.popOrNull()) |operator| {
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
                try createOperator(allocator, x, outputStack);
            }
            try operatorStack.append(token);
        }
    };
}

fn createOperator(allocator: Allocator, token: Token, outputStack: *ArrayList(Value)) !void {
    const left = outputStack.pop();
    const right = outputStack.pop();
    const val = switch(token) {
        .mul => Value{ .mul = try util.create(allocator, TupleType, .{
            left,
            right
        })},
        .div => Value{ .div = try util.create(allocator, TupleType, .{
            left,
            right
        })},
        .sub => Value{ .sub = try util.create(allocator, TupleType, .{
            left,
            right
        })},
        .add => Value{ .add = try util.create(allocator, TupleType, .{
            left,
            right
        })},
        .lparen => unreachable,
        .rparen => unreachable,
        .num => unreachable
    };
    try outputStack.append(val);
}

// We're going to try implement the shunting yard algorithm
pub fn parseExpr(allocator: Allocator, input: []const Token) !Value {
    var outputStack = ArrayList(Value).init(allocator);
    var operatorStack = ArrayList(Token).init(allocator);
    var sliceIter = SliceIter(Token).init(input);

    while (sliceIter.next()) |token| {
        try handleToken(allocator, token, &outputStack, &operatorStack);
    }

    while (operatorStack.popOrNull()) |token| {
        try createOperator(allocator, token, &outputStack);
    }

    return outputStack.pop();
}
