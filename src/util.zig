const std = @import("std");
const frontend = @import("frontend.zig");
const backend = @import("backend.zig");

const Allocator = std.mem.Allocator;

const Value = frontend.Value;
const LabelledValue = backend.LabelledValue;
const Token = frontend.Token;

pub fn create(allocator: Allocator, comptime T: type, value: anytype) !*T {
    const typedValue: T = value;
    const x = try allocator.create(T);
    x.* = typedValue;

    return x;
}

pub fn eval(val: Value) i32 {
    return switch (val) {
        .int => |v| v,
        .add => |v| eval(v[0].*) + eval(v[1].*),
        .sub => |v| {
            std.debug.print("\n{}, {}\n", .{eval(v[0].*), eval(v[1].*)});
            return eval(v[0].*) - eval(v[1].*);
        },
        .mul => |v| eval(v[0].*) * eval(v[1].*),
        .div => |v| {
            std.debug.print("\n{}, {}\n", .{eval(v[0].*), eval(v[1].*)});
            return std.math.divExact(i32, eval(v[0].*), eval(v[1].*)) catch @panic("OOPS");
        },
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
            printTree(input.mul.@"0".*);
            printTree(input.mul.@"1".*);
            std.debug.print("*", .{});
        },
        .div => {
            printTree(input.div.@"0".*);
            printTree(input.div.@"1".*);
            std.debug.print("/", .{});
        },
        .sub => {
            printTree(input.sub.@"0".*);
            printTree(input.sub.@"1".*);
            std.debug.print("-", .{});
        },
        .add => {
            printTree(input.add.@"0".*);
            printTree(input.add.@"1".*);
            std.debug.print("+", .{});
        },
        .int => std.debug.print("{d}", .{input.int}),
    }
}

pub fn freeVal(allocator: Allocator, val: *Value) void {
    switch (val.*) {
        .int => |_| {},
        .add, .sub, .mul, .div => |v| {
            freeVal(allocator, v[0]);
            freeVal(allocator, v[1]);
        },
    }

    allocator.destroy(val);
}

pub fn freeLVal(allocator: Allocator, lval: *LabelledValue) void {
    switch(lval.*.val) {
        .int => |_| {},
        .add, .sub, .mul, .div => |v| {
            freeLVal(allocator, v[0]);
            freeLVal(allocator, v[1]);
        }
    }

    allocator.destroy(lval);
}
