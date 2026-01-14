const std = @import("std");

const filesystem = @import("filesystem.zig");

const Allocator = std.mem.Allocator;

const Replacement = struct { []const u8, []const u8 };

const BASE_LAYOUT_PATH = "templates/layouts/base.html";

pub fn renderIndexPage(gpa: Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = try filesystem.load_file(allocator, "templates/views/index.html");
    // TODO: Render template parts before finalizing page
    const base_layout = try filesystem.load_file(allocator, BASE_LAYOUT_PATH);
    const replacements = [_]Replacement{
        .{ "{{title}}", "Joshua Ibrom" },
        .{ "{{content}}", template },
    };
    var page = try allocator.dupe(u8, base_layout);
    for (replacements) |repl| {
        const needle, const replacement = repl;
        const prev_page = page;
        page = try std.mem.replaceOwned(u8, allocator, prev_page, needle, replacement);
    }
    const final_page = try gpa.dupe(u8, page);
    return final_page;
}
