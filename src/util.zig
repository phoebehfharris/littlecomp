const std = @import("std");
const frontend = @import("frontend.zig");

const Allocator = std.mem.Allocator;

const Value = frontend.Value;
const Token = frontend.Token;

pub fn create(allocator: Allocator, comptime T: type, value: anytype) !*T {
    const x = try allocator.create(T);
    x.* = value;

    return x;
}

pub fn eval(val: Value) i32 {
    return switch (val) {
        .int => |v| v,
        .add => |v| eval(v.*[0]) + eval(v.*[1]),
        .sub => |v| eval(v.*[0]) - eval(v.*[1]),
        .mul => |v| eval(v.*[0]) * eval(v.*[1]),
        .div => |v| @divExact(eval(v.*[0]), eval(v.*[1])),
    };
}

pub fn printToken(input: Token) void {
    switch(input) {
        .num => |num| std.debug.print("{d}", .{num}),
        .add => std.debug.print("+", .{}),
        .sub => std.debug.print("-", .{}),
        .mul => std.debug.print("*", .{}),
        .div => std.debug.print("/", .{}),
        .lparen => std.debug.print("(", .{}),
        .rparen => std.debug.print(")", .{}),
    }
}

pub fn SliceIter(comptime T: type) type{
    return struct {
        slice: []const T,
        index: usize,

        pub fn init(x: []const T) SliceIter(T) {
            return SliceIter(T){
                .slice = x,
                .index = 0,
            };
        }

        pub fn next(self: *SliceIter(T)) ?T {
            if (self.index < self.slice.len) {
                const tmp = self.index;
                self.index += 1;
                return self.slice[tmp];
            } else {
                return null;
            }
        }

        pub fn peek(self: *SliceIter(T)) ?T {
            if (self.index < self.slice.len) {
                const tmp = self.index;
                return self.slice[tmp];
            } else {
                return null;
            }
        }
    };
}

pub fn printTree(input: Value) void {
    switch(input) {
        .mul => {
            printTree(input.mul.@"0");
            printTree(input.mul.@"1");
            std.debug.print("*", .{});
        },
        .div => {
            printTree(input.div.@"0");
            printTree(input.div.@"1");
            std.debug.print("/", .{});
        },
        .sub => {
            printTree(input.sub.@"0");
            printTree(input.sub.@"1");
            std.debug.print("-", .{});
        },
        .add => {
            printTree(input.add.@"0");
            printTree(input.add.@"1");
            std.debug.print("+", .{});
        },
        .int => std.debug.print("{d}", .{input.int}),
    }
}

pub fn free(allocator: Allocator, val: *const Value) void {
    switch (val.*) {
        .add, .sub, .mul, .div => |v| {
            free(allocator, &v[0]);
            free(allocator, &v[1]);
            allocator.destroy(v);
        },
        else => {},
    }
}
