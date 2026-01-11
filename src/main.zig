const std = @import("std");
const filesystem = @import("filesystem.zig");

pub fn main() void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer if (gpa.deinit() == .leak) std.debug.panic("[E] Memory leak detected.\n", .{});
    const allocator = gpa.allocator();

    var stderr_buf: [1024]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_writer.interface;

    const content_listing = get_content_dir_files(allocator, stderr);
    defer content_listing.deinit(allocator);

    for (content_listing.employment) |f| {
        const file_content = filesystem.load_file(allocator, f) catch @panic("uh oh");
        defer allocator.free(file_content);
        std.debug.print("{s}\n", .{file_content});
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
