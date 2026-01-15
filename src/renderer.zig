const std = @import("std");

const filesystem = @import("filesystem.zig");

const Allocator = std.mem.Allocator;

pub const Replacement = struct { []const u8, []const u8 };

const BASE_LAYOUT_PATH = "templates/layouts/base.html";

pub fn renderIndexPage(gpa: Allocator) ![]const u8 {
    const template = try filesystem.load_file(gpa, "templates/views/index.html");
    defer gpa.free(template);
    // TODO: Render template parts before finalizing page
    //const base_layout = try filesystem.load_file(allocator, BASE_LAYOUT_PATH);
    const replacements = [_]Replacement{
        .{ "{{title}}", "Joshua Ibrom" },
        .{ "{{content}}", template },
    };
    return renderPartial(gpa, BASE_LAYOUT_PATH, &replacements);
}

pub fn renderPartial(allocator: Allocator, partial_path: []const u8, replacements: []const Replacement) ![]const u8 {
    const partial = try filesystem.load_file(allocator, partial_path);
    defer allocator.free(partial);
    var page = try allocator.dupe(u8, partial);
    for (replacements) |repl| {
        const needle, const replacement = repl;
        const prev_page = page;
        page = try std.mem.replaceOwned(u8, allocator, prev_page, needle, replacement);
        allocator.free(prev_page);
    }
    return page;
}
