const std = @import("std");

const Allocator = std.mem.Allocator;

const EMPLOYMENT_DIRNAME = "employment";
const PROJECTS_DIRNAME = "projects";

/// Holds a listing of filenames and their paths from a content directory.
pub const ContentListing = struct {
    const Self = @This();

    employment: []const []const u8,
    projects: []const []const u8,

    /// Scans a provided content directory for a listing of employment and
    /// project HTML files.
    pub fn fromContentDir(allocator: Allocator, path: []const u8) !Self {
        var content_dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => return error.NoContentDirectory,
            else => return err,
        };
        defer content_dir.close();

        const employment_path =
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, EMPLOYMENT_DIRNAME });
        defer allocator.free(employment_path);
        var employment_dir = content_dir.openDir(EMPLOYMENT_DIRNAME, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => return error.NoEmploymentDirectory,
            else => return err,
        };
        defer employment_dir.close();

        const projects_path =
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, PROJECTS_DIRNAME });
        defer allocator.free(projects_path);
        var projects_dir = content_dir.openDir(PROJECTS_DIRNAME, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => return error.NoProjectsDirectory,
            else => return err,
        };
        defer projects_dir.close();

        const employment_files = try Self.scanDir(
            allocator,
            &employment_dir,
            employment_path,
        );
        const projects_files = try Self.scanDir(
            allocator,
            &projects_dir,
            projects_path,
        );

        return Self{
            .employment = employment_files,
            .projects = projects_files,
        };
    }

    /// Scans an individual directory for the HTML files in that directory.
    fn scanDir(allocator: Allocator, dir: *const std.fs.Dir, path: []const u8) ![][]const u8 {
        var listing: std.ArrayList([]const u8) = .empty;
        var walker = try dir.walk(allocator);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            if (std.mem.endsWith(u8, entry.basename, ".html")) {
                const fname = try allocator.dupe(u8, entry.basename);
                defer allocator.free(fname);
                const fpath = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, fname });
                try listing.append(allocator, fpath);
            }
        }
        return listing.toOwnedSlice(allocator);
    }

    pub fn deinit(self: Self, allocator: Allocator) void {
        for (self.employment) |item| {
            allocator.free(item);
        }
        allocator.free(self.employment);

        for (self.projects) |item| {
            allocator.free(item);
        }
        allocator.free(self.projects);
    }
};

/// Loads a file in its entirety into a string. Really just a wrapper for
/// `std.fs.cwd().readFileAlloc` with a 16MB max read size.
///
/// Returns `error.FileTooBig` if the file is larger than 16MB in size.
pub fn load_file(allocator: Allocator, path: []const u8) ![]const u8 {
    const max_bytes = 16 * 1024 * 1024;
    return std.fs.cwd().readFileAlloc(allocator, path, max_bytes);
}

pub fn write_file(placement_path: []const u8, filename: []const u8, content: []const u8) !void {
    var path_parts = try std.fs.path.componentIterator(placement_path);
    while (path_parts.next()) |comp| {
        const parent_path = comp.path[0 .. comp.path.len - comp.name.len];
        var dir, const should_close = switch (parent_path.len) {
            0 => .{ std.fs.cwd(), false },
            else => .{ try std.fs.cwd().openDir(parent_path, .{}), true },
        };
        defer if (should_close) dir.close();
        try ensure_dir_exists(&dir, comp.name);
    }
    var dir = try std.fs.cwd().openDir(placement_path, .{});
    defer dir.close();
    const f = try dir.createFile(filename, .{});
    defer f.close();
    _ = try f.write(content);
}

fn ensure_dir_exists(dir: *const std.fs.Dir, dirname: []const u8) !void {
    dir.makeDir(dirname) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}
