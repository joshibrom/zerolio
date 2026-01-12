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
    const arena_allocator = arena.allocator();

    for (content_listing.employment) |f| {
        const file_content = filesystem.load_file(arena_allocator, f) catch @panic("uh oh");
        defer arena_allocator.free(file_content);
        const entry = parser.parseEntry(arena_allocator, file_content, .Employment) catch @panic("There was an issue parsing bro");
        defer entry.deinit(arena_allocator);
        std.debug.print("title: {s}\n", .{entry.title});
        std.debug.print("{s}\n", .{entry.text});
    }
    // NOTE: I would like to use an arena so that each entry type resets all memory when no longer needed
    if (!arena.reset(.free_all)) @panic("Could not free all memory."); // FIXME: Update method of panicking
    for (content_listing.projects) |f| {
        const file_content = filesystem.load_file(arena_allocator, f) catch @panic("uh oh");
        defer arena_allocator.free(file_content);
        const entry = parser.parseEntry(arena_allocator, file_content, .Project) catch @panic("There was an issue parsing bro");
        defer entry.deinit(arena_allocator);
        std.debug.print("title: {s}\n", .{entry.title});
        for (entry.data.Project.tags) |t| {
            std.debug.print("  - '{s}'\n", .{t});
        }
    }
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
