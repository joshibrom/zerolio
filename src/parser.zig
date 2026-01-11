const std = @import("std");
const models = @import("models.zig");

const Allocator = std.mem.Allocator;

const Entry = models.Entry;
const EntryCategory = models.EntryCategory;

const METADATA_BEGIN = "<!-- METADATA\n";
const METADATA_END = "METADATA -->";

/// Parses some text contents from an HTML file into an `Entry`.
///
/// Assumes that the file has a METADATA header comment (else throws
/// `error.NoMetadataHeader`) that is formatted such as
/// ```
/// <!-- METADATA
/// [key]: [value]...
/// METADATA --->
/// ```
/// If there is no closing `error.NoMetadataEnd` will be returned.
pub fn parseEntry(allocator: Allocator, text: []const u8, category: EntryCategory) !Entry {
    // Check that the file starts with the metadata header
    if (!std.mem.startsWith(u8, text, METADATA_BEGIN)) {
        return error.NoMetadataHeader;
    }
    // Get where the metadata header ends if there is an end to it
    const metadata_end_idx = std.mem.indexOf(u8, text, METADATA_END) orelse return error.NoMetadataEnd;

    // Slice out the metadata and parse the category-specific parts of it
    const metadata = text[METADATA_BEGIN.len..metadata_end_idx];
    const data = switch (category) {
        .Employment => models.EntryData{ .Employment = try parseEmploymentData(metadata) },
        .Project => models.EntryData{ .Project = try parseProjectData(allocator, metadata) },
    };
    // Parse the remaining general fields
    var title: []const u8 = undefined;
    var start_date: []const u8 = undefined;
    var end_date: []const u8 = "Current";
    var line_iter = std.mem.splitScalar(u8, metadata, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        var pair_iter = std.mem.tokenizeScalar(u8, line, ':');
        const key = pair_iter.next() orelse return error.MissingMetadataKey;
        const val = pair_iter.next() orelse "";
        if (std.mem.eql(u8, key, "TITLE")) title = val;
        if (std.mem.eql(u8, key, "START")) start_date = val;
        if (std.mem.eql(u8, key, "END")) end_date = val;
    }
    return .{
        .title = title,
        .dates = .{
            .s = start_date,
            .e = end_date,
        },
        .data = data,
        .text = text[metadata_end_idx + METADATA_END.len ..],
    };
}

fn parseEmploymentData(metadata: []const u8) !models.EmploymentEntryData {
    var line_iter = std.mem.splitScalar(u8, metadata, '\n');
    var company: []const u8 = undefined;
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        var pair_iter = std.mem.tokenizeScalar(u8, line, ':');
        const key = pair_iter.next() orelse return error.MissingMetadataKey;
        const val = pair_iter.next() orelse "";
        if (std.mem.eql(u8, key, "COMPANY")) company = val;
    }
    // TODO: Ensure everything is defined
    return .{ .company = company };
}

fn parseProjectData(allocator: Allocator, metadata: []const u8) !models.ProjectEntryData {
    var line_iter = std.mem.splitScalar(u8, metadata, '\n');
    var brief: []const u8 = undefined;
    var image: []const u8 = undefined;
    var tags: std.ArrayList([]const u8) = .empty;
    var deployments: std.ArrayList([]const u8) = .empty;
    var repositories: std.ArrayList([]const u8) = .empty;
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        var pair_iter = std.mem.tokenizeScalar(u8, line, ':');
        const key = pair_iter.next() orelse return error.MissingMetadataKey;
        const val = pair_iter.next() orelse "";
        if (std.mem.eql(u8, key, "BRIEF")) brief = val;
        if (std.mem.eql(u8, key, "IMAGE")) image = val;
        if (std.mem.eql(u8, key, "TAGS")) {
            var tag_iter = std.mem.tokenizeScalar(u8, val, ',');
            while (tag_iter.next()) |tag| {
                try tags.append(allocator, tag);
            }
        }
        if (std.mem.eql(u8, key, "DEPLOYMENTS")) {
            var dep_iter = std.mem.tokenizeScalar(u8, val, ',');
            while (dep_iter.next()) |dep| {
                try deployments.append(allocator, dep);
            }
        }
        if (std.mem.eql(u8, key, "REPOSITORIES")) {
            var rep_iter = std.mem.tokenizeAny(u8, val, ", ");
            while (rep_iter.next()) |rep| {
                try repositories.append(allocator, rep);
            }
        }
    }
    // TODO: Ensure everything is defined
    return .{
        .brief = brief,
        .image = image,
        .tags = try tags.toOwnedSlice(allocator),
        .deployments = try deployments.toOwnedSlice(allocator),
        .repositories = try repositories.toOwnedSlice(allocator),
    };
}
