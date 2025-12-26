const std = @import("std");
const frontend = @import("frontend.zig");
const backend = @import("backend.zig");
const util = @import("util.zig");

const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;

const Value = frontend.Value;
const lexExpr = frontend.lexExpr;
const parseExpr = frontend.parseExpr;

const writeCode = backend.writeCode;

const free = util.free;
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

    const v = try util.create(allocator, Value, try parseExpr(allocator, tokens));
    defer free(allocator, v);

    printTree(v.*);

    std.debug.print("{d}", .{eval(v.*)});
    const file = try std.fs.cwd().createFile("output.s", .{ .read = true });
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var writer = file.writer(&buffer);
    const interface = &writer.interface;

    try interface.print(".text\n", .{});
    try interface.writeAll(".globl _start\n");
    try interface.writeAll("_start:\n");
    try writeCode(interface, v.*);
    try interface.writeAll("mov $1, %eax \n");
    try interface.writeAll("popl %ebx\n");
    try interface.writeAll("int $0x80\n");

    try interface.flush();
}
