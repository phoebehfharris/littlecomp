const std = @import("std");
const frontend = @import("frontend.zig");
const util = @import("util.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Value = frontend.Value;
const ValueType = frontend.ValueType;

const TaggedTupleType = struct{*LabelledValue, *LabelledValue};
pub const LabelledValue = struct{val: union(ValueType) { int:  i32, add: TaggedTupleType, sub: TaggedTupleType, mul: TaggedTupleType, div: TaggedTupleType}, label: i32};

pub fn getRegisterName(index: u8) []const u8 {
    return switch(index) {
        0 => "eax",
        1 => "ebx",
        2 => "ecx",
        3 => "edx",
        else => @panic("Illegal register index"),
    };
}

fn removeFromReglist(allocator: std.mem.Allocator, regList: ArrayList(u8), reg: u8) !ArrayList(u8) {
    var newList = try regList.clone(allocator);

    for (regList.items, 0..) |ireg, i| {
        if (ireg == reg) {
            _ = newList.orderedRemove(i);
            break;
        }
    }

    return newList;
}

fn writeOperator(writer: *std.Io.Writer, val: LabelledValue, lreg: []const u8, rreg: []const u8) !void {
    switch(val.val) {
        .int => @panic("Not an operator!"),
        .add => try writer.print("add {s}, {s}\n", .{rreg, lreg}),
        .sub => try writer.print("sub {s}, {s}\n", .{rreg, lreg}),
        .mul => try writer.print("imul {s}, {s}\n", .{rreg, lreg}),
        .div => {
            try writer.print("xchg eax {s}", .{lreg});
            try writer.print("cdq\n", .{});
            try writer.print("idiv {s}\n", .{rreg});
            try writer.print("xchg eax {s}", .{lreg});
        },
    }
}

// We'll assume we can use eax, ebx, ecx, edx
pub fn writeCodeSethiUllman(allocator: std.mem.Allocator, writer: *std.Io.Writer, lval: LabelledValue, regList: ArrayList(u8), tmp: u8, left: bool) !u8 {
    switch(lval.val) {
        .int => |v| {
            if (!left) {
            @panic("Should be unreachable!");
            }

            try writer.print("movl ${}, %{s}\n", .{v, getRegisterName(regList.items[0])});

            return regList.items[0];
        },
        .add, .sub, .mul, .div => |v| {
            const leftChild = v[0].*;
            const rightChild = v[1].*;

            if (rightChild.label == 0) {
                const r =  try writeCodeSethiUllman(allocator, writer, leftChild, regList, tmp, true);
                try writeOperator(
                    writer,
                    lval,
                    try std.fmt.allocPrint(allocator, "%{s}", .{getRegisterName(r)}),
                    try std.fmt.allocPrint(allocator, "${}", .{rightChild.val.int})
                    );

                return r;
            } else if (leftChild.label >= rightChild.label and rightChild.label > 0 and rightChild.label < regList.items.len) {
                const r1 = try writeCodeSethiUllman(allocator, writer, leftChild, regList, tmp, true);
                const r2 = try writeCodeSethiUllman(allocator, writer, rightChild, try removeFromReglist(allocator, regList, r1), tmp, false);

                try writeOperator(
                    writer,
                    lval,
                    try std.fmt.allocPrint(allocator, "%{s}", .{getRegisterName(r1)}),
                    try std.fmt.allocPrint(allocator, "%{s}", .{getRegisterName(r2)})
                );

                return r1;
            } else if (leftChild.label < rightChild.label and leftChild.label < regList.items.len) {
                const r1 = try writeCodeSethiUllman(allocator, writer, rightChild, regList, tmp, false);
                const r2 = try writeCodeSethiUllman(allocator, writer, leftChild, try removeFromReglist(allocator, regList, r1), tmp, true);

                try writeOperator(
                    writer,
                    lval,
                    // TODO Fix the prefixes
                    try std.fmt.allocPrint(allocator, "%{s}", .{getRegisterName(r1)}),
                    try std.fmt.allocPrint(allocator, "%{s}", .{getRegisterName(r2)})
                );

                return r1;
            } else if (leftChild.label >= regList.items.len and rightChild.label >= regList.items.len) {
                const r1 = try writeCodeSethiUllman(allocator, writer, rightChild, regList, tmp, false);
                try writer.print("pushl %{s}", .{getRegisterName(r1)});
                const r2 = try writeCodeSethiUllman(allocator, writer, leftChild, regList, tmp+1, true);

                try writeOperator(
                    writer,
                    lval,
                    try std.fmt.allocPrint(allocator, "%{s}", .{getRegisterName(r2)}),
                    "(%esp)"
                );

                try writer.print("subl $4, %esp", .{});

                return r2;
            } else {
                @panic("Should be unreachable!");
            }
        }
    }
}


pub fn writeCode(writer: *std.Io.Writer, val: Value) !void {
    switch (val) {
        .int => |v| {
            try writer.print("movl ${}, %eax\n", .{v});
            try writer.writeAll("pushl %eax\n");
        },
        .add => |v| {
            try writeCode(writer, v.*[0]);
            try writeCode(writer, v.*[1]);
            try writer.writeAll("popl %eax\n");
            try writer.writeAll("popl %ebx\n");
            try writer.writeAll("add %eax, %ebx\n");
            try writer.writeAll("pushl %ebx\n");
        },
        .sub => |v| {
            try writeCode(writer, v.*[0]);
            try writeCode(writer, v.*[1]);
            try writer.writeAll("popl %ebx\n");
            try writer.writeAll("popl %eax\n");
            try writer.writeAll("sub %eax, %ebx\n");
            try writer.writeAll("pushl %ebx\n");
        },
        .mul => |v| {
            try writeCode(writer, v.*[0]);
            try writeCode(writer, v.*[1]);
            try writer.writeAll("popl %eax\n");
            try writer.writeAll("popl %ebx\n");
            try writer.writeAll("imul %eax, %ebx\n");
            try writer.writeAll("pushl %ebx\n");
        },
        .div => |v| {
            try writeCode(writer, v.*[0]);
            try writeCode(writer, v.*[1]);
            try writer.writeAll("popl %ebx\n");
            try writer.writeAll("cdq\n");
            try writer.writeAll("popl %eax\n");
            try writer.writeAll("idiv %ebx\n");
            try writer.writeAll("pushl %ebx\n");
        },
    }
}

pub fn labelTree(allocator: Allocator, val: Value, left: bool) !LabelledValue {
    return switch(val) {
        .int => |v| if (left)
            LabelledValue{.val = .{.int = v}, .label = 1}
        else
            LabelledValue{.val = .{.int = v}, .label = 0},
        .add, .mul, .sub, .div => |v| {
            const leftChild: LabelledValue = try labelTree(allocator, v[0].*, true);
            const rightChild: LabelledValue = try labelTree(allocator, v[1].*, false);

            if (leftChild.label == rightChild.label) {
                return createLabelledValue(
                    TaggedTupleType{
                        try util.create(allocator, LabelledValue, leftChild),
                        try util.create(allocator, LabelledValue, rightChild)
                    },
                    val,
                    leftChild.label + 1
                );
            } else {
                return createLabelledValue(
                    TaggedTupleType{
                        try util.create(allocator, LabelledValue, leftChild),
                        try util.create(allocator, LabelledValue, rightChild)
                    },
                    val,
                    leftChild.label + 1
                );
            }
        }
    };
}


pub fn createLabelledValue(tpl: TaggedTupleType, val: Value, label: i32) LabelledValue {
    switch(val) {
        .int => @panic("Don't provide an int!"),
        .add => return LabelledValue {
            .val = .{
                .add = tpl
            },
            .label = label
        },
        .sub => return LabelledValue {
            .val = .{
                .sub = tpl
            },
            .label = label
        },
        .mul => return LabelledValue {
            .val = .{
                .mul = tpl
            },
            .label = label
        },
        .div => return LabelledValue {
            .val = .{
                .div = tpl
            },
            .label = label
        },

    }
}
