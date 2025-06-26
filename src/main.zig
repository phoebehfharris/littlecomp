const std = @import("std");
const frontend = @import("frontend.zig");
const backend = @import("backend.zig");
const utils = @import("util.zig");

const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;

const Value = frontend.Value;
const lexExpr = frontend.lexExpr;
const parseExpr = frontend.parseExpr;

const writeCode = backend.writeCode;

const free = utils.free;
const printToken = utils.printToken;
const printTree = utils.printTree;
const eval = utils.eval;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const input = "10 * 2 - 3";
    const tokens = try lexExpr(allocator, input);

    for (tokens) |token| {
        printToken(token);
    }
    std.debug.print("\n", .{});

    const x = try parseExpr(allocator, tokens);
    defer free(allocator, &x);

    printTree(x);

    std.debug.print("{d}", .{eval(x)});
    const file = try std.fs.cwd().createFile("output.s", .{ .read = true });
    defer file.close();

    const writer = file.writer();

    try writer.writeAll(".text\n");
    try writer.writeAll(".globl _start\n");
    try writer.writeAll("_start:\n");
    try writeCode(writer, x);
    try writer.writeAll("mov $1, %eax \n");
    try writer.writeAll("popl %ebx\n");
    try writer.writeAll("int $0x80\n");
}
