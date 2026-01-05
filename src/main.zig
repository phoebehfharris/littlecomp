const std = @import("std");
const frontend = @import("frontend.zig");
const backend = @import("backend.zig");
const util = @import("util.zig");

const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;

const Value = frontend.Value;
const LabelledValue = backend.LabelledValue;
const lexExpr = frontend.lexExpr;
const parseExpr = frontend.parseExpr;

const writeCode = backend.writeCode;
const writeCodeSethiUllman = backend.writeCodeSethiUllman;
const labelTree = backend.labelTree;
const getRegistername = backend.getRegisterName;

const freeVal = util.freeVal;
const freeLVal = util.freeLVal;
const printToken = util.printToken;
const printTree = util.printTree;
const eval = util.eval;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const input = "10 * 2 - 3";
    const tokens = try lexExpr(allocator, input);

    for (tokens) |token| {
        printToken(token);
    }
    std.debug.print("\n", .{});

    const val = try util.create(allocator, Value, try parseExpr(allocator, tokens));
    defer freeVal(allocator, val);

    const labelledVal = try util.create(allocator, LabelledValue, try labelTree(allocator, val.*, true));
    defer freeLVal(allocator, labelledVal);
    var regList : std.ArrayList(u8) = .empty;

    try regList.append(allocator, 0);
    try regList.append(allocator, 1);
    try regList.append(allocator, 2);
    try regList.append(allocator, 3);

    printTree(val.*);

    std.debug.print("{d}", .{eval(val.*)});
    const file = try std.fs.cwd().createFile("output.s", .{ .read = true });
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var writer = file.writer(&buffer);
    const interface = &writer.interface;

    try interface.print(".text\n", .{});
    try interface.writeAll(".globl _start\n");
    try interface.writeAll("_start:\n");
    // try writeCode(interface, val.*);
    const r = try writeCodeSethiUllman(allocator, interface, labelledVal.*, regList, 0, true);
    try interface.print("mov %{s}, %ebx\n", .{getRegistername(r)});
    try interface.writeAll("mov $1, %eax \n");
    try interface.writeAll("int $0x80\n");

    try interface.flush();
}
