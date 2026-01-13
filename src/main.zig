const std = @import("std");
const filesystem = @import("filesystem.zig");
const parser = @import("parser.zig");

pub fn main() void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer if (gpa.deinit() == .leak) std.debug.panic("[E] Memory leak detected.\n", .{});
    const gpa_allocator = gpa.allocator();

    var stderr_buf: [1024]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_writer.interface;

    const content_listing = get_content_dir_files(gpa_allocator, stderr);
    defer content_listing.deinit(gpa_allocator);

    var arena = std.heap.ArenaAllocator.init(gpa_allocator);
    defer if (!arena.reset(.free_all)) @panic("Could not free all memory."); // FIXME: Update method of panicking

    render_content_listing(&arena, stderr, &content_listing);

    const index = @import("renderer.zig").renderIndexPage(gpa_allocator) catch @panic("Couldn't render page.");
    defer gpa_allocator.free(index);

    std.debug.print("\n\n---\n{s}\n---\n", .{index});

    filesystem.write_file("public", "index.html", index) catch |err| std.debug.panic("[E] {}\n", .{err});
}

/// Helper function to get filenames from content directory and handle errors.
/// This function is primarily intended to ensure that the main function does
/// not become too cluttered and enforces separation of concerns.
fn get_content_dir_files(allocator: std.mem.Allocator, stderr: *std.io.Writer) filesystem.ContentListing {
    return filesystem.ContentListing.fromContentDir(allocator, "content") catch |err| {
        switch (err) {
            error.NoContentDirectory => stderr.print("[E] Content directory does not exist!\n", .{}) catch {},
            error.NoEmploymentDirectory => stderr.print("[E] Employment directory does not exist!\n", .{}) catch {},
            error.NoProjectsDirectory => stderr.print("[E] Projects directory does not exist!\n", .{}) catch {},
            else => stderr.print("[E] Error when scanning content directory: {}\n", .{err}) catch {},
        }
        stderr.flush() catch {};
        std.process.exit(1);
    };
}

/// Renders files from the listing of content.
fn render_content_listing(arena: *std.heap.ArenaAllocator, stderr: *std.io.Writer, content_listing: *const filesystem.ContentListing) void {
    // TODO: Determine if there's a better way of dealing with the arena and rendering files.
    // I still need to figure out how I'd like to keep memory alive for things like rendering
    // the list of projects and stuff on common pages.
    const allocator = arena.allocator();
    for (content_listing.employment) |f| {
        const file_content = filesystem.load_file(allocator, f) catch |err| {
            stderr.print("[E] Could not load file: {}.\n", .{err}) catch {};
            std.process.exit(1);
        };
        const entry = parser.parseEntry(allocator, file_content, .Employment) catch |err| {
            stderr.print("[E] Could not parse entry: {}.\n", .{err}) catch {};
            std.process.exit(1);
        };
        std.debug.print("title: {s}\n", .{entry.title});
        std.debug.print("{s}\n", .{entry.text});
    }

    if (!arena.reset(.retain_capacity)) stderr.print("[E] Could not reset arena.", .{}) catch {};

    for (content_listing.projects) |f| {
        const file_content = filesystem.load_file(allocator, f) catch |err| {
            stderr.print("[E] Could not load file: {}.\n", .{err}) catch {};
            std.process.exit(1);
        };
        const entry = parser.parseEntry(allocator, file_content, .Project) catch |err| {
            stderr.print("[E] Could not parse entry: {}.\n", .{err}) catch {};
            std.process.exit(1);
        };
        std.debug.print("title: {s}\n", .{entry.title});
        for (entry.data.Project.tags) |t| {
            std.debug.print("  - '{s}'\n", .{t});
        }
    }
}
