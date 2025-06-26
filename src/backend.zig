const std = @import("std");
const frontend = @import("frontend.zig");

const Value = frontend.Value;
const ValueType = frontend.Value;

const TaggedTupleType = struct{LabelledValue, LabelledValue};
const LabelledValue = struct{val: union(ValueType) { int:  i32, add: *TaggedTupleType, sub: *TaggedTupleType, mul: *TaggedTupleType, div: *TaggedTupleType}, label: i32};

pub fn writeCode(writer: std.fs.File.Writer, val: Value) !void {
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

pub fn labelTree(val: Value, left: bool) LabelledValue {
    switch(val) {
        .int => |v| if (left)
            LabelledValue{.val = TaggedTupleType{.int = v}, .label = 1}
        else
            LabelledValue{.val = TaggedTupleType{.int = v}, .label = 0},
        else => |v| {
            const leftChild: LabelledValue = labelTree(v.*[0], true);
            const rightChild: LabelledValue = labelTree(v.*[1], false);

            if (leftChild.label == rightChild.label) {
                return LabelledValue{.val = .{.mul = TaggedTupleType{leftChild, rightChild}}, .label = leftChild.label + 1};
            } else {
                return LabelledValue{.val = .{.mul = TaggedTupleType{leftChild, rightChild}}, .label = @max(leftChild.label, rightChild.label)};
            }
        }
    }
}
