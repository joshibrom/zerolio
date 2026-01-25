const std = @import("std");
const models = @import("models.zig");

const Allocator = std.mem.Allocator;

const Entry = models.Entry;
const EntryCategory = models.EntryCategory;

const METADATA_BEGIN = "<!-- METADATA\n";
const METADATA_END = "METADATA -->";

const DeferredString = struct {
    const Self = @This();

    val: []const u8,
    set: bool,

    pub fn new(default_value: ?[]const u8) Self {
        return if (default_value) |val|
            .{ .val = val, .set = true }
        else
            .{ .val = undefined, .set = false };
    }

    pub fn update(self: *Self, val: []const u8) void {
        self.val = val;
        self.set = true;
    }
};
const KeyValPair = struct { []const u8, []const u8 };

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

    var kv_store: std.ArrayList(KeyValPair) = .empty;
    defer kv_store.deinit(allocator);
    var line_iter = std.mem.splitScalar(u8, metadata, '\n');
    while (line_iter.next()) |line| {
        const kv = get_kv(line) catch continue;
        try kv_store.append(allocator, kv);
    }

    const data = switch (category) {
        .Employment => models.EntryData{ .Employment = try parseEmploymentData(&kv_store.items) },
        .Project => models.EntryData{ .Project = try parseProjectData(allocator, &kv_store.items) },
    };
    // Parse the remaining general fields
    var title: DeferredString = .new(null);
    var start_date: DeferredString = .new(null);
    var end_date: DeferredString = .new("Current");
    for (kv_store.items) |kv| {
        const key, const val = kv;
        if (std.mem.eql(u8, key, "TITLE")) title.update(val);
        if (std.mem.eql(u8, key, "START")) start_date.update(val);
        if (std.mem.eql(u8, key, "END")) end_date.update(val);
    }
    if (!title.set or !start_date.set) return error.RequiredFieldsNotInitialized; // TODO: Handle each field
    return .{
        .title = title.val,
        .dates = .{
            .s = start_date.val,
            .e = end_date.val,
        },
        .data = data,
        .text = text[metadata_end_idx + METADATA_END.len ..],
    };
}

fn parseEmploymentData(kv_list: *[]KeyValPair) !models.EmploymentEntryData {
    var company: DeferredString = .new(null);
    for (kv_list.*) |kv| {
        const key, const val = kv;
        if (std.mem.eql(u8, key, "COMPANY")) company.update(val);
    }
    if (!company.set) return error.NoCompanyGiven;
    return .{ .company = company.val };
}

fn parseProjectData(allocator: Allocator, kv_list: *[]KeyValPair) !models.ProjectEntryData {
    var brief: DeferredString = .new(null);
    var image: DeferredString = .new(null);
    var tags: std.ArrayList([]const u8) = .empty;
    var deployments: std.ArrayList([]const u8) = .empty;
    var repositories: std.ArrayList([]const u8) = .empty;
    for (kv_list.*) |kv| {
        const key, const val = kv;
        if (std.mem.eql(u8, key, "BRIEF")) brief.update(val);
        if (std.mem.eql(u8, key, "IMAGE")) image.update(val);
        if (std.mem.eql(u8, key, "TAGS")) try tags.append(allocator, val);
        if (std.mem.eql(u8, key, "DEPLOYMENTS")) try deployments.append(allocator, val);
        if (std.mem.eql(u8, key, "REPOSITORIES")) try repositories.append(allocator, val);
    }
    if (!brief.set or !image.set) return error.RequiredFieldsNotInitialized; // TODO: Handle each field
    return .{
        .brief = brief.val,
        .image = image.val,
        .tags = try tags.toOwnedSlice(allocator),
        .deployments = try deployments.toOwnedSlice(allocator),
        .repositories = try repositories.toOwnedSlice(allocator),
    };
}

/// Gets a key and value from a line that is of the form `[key]: [value]`.
fn get_kv(line: []const u8) !KeyValPair {
    var idx: usize = 0;
    while (idx < line.len and std.ascii.isWhitespace(line[idx])) {
        idx += 1;
    }
    const key_start: usize = idx;
    while (idx < line.len and line[idx] != ':') {
        idx += 1;
    }
    if (idx == line.len) return error.NoSeparatorInLine;
    const key_end = idx;
    idx += 1;
    while (idx < line.len and std.ascii.isWhitespace(line[idx])) {
        idx += 1;
    }
    return .{ line[key_start..key_end], line[idx..line.len] };
}
