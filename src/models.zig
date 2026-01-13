/// Stores a range of dates from a start `s` to an end `e`.
pub const DateRange = struct {
    s: []const u8,
    e: []const u8 = "Current",
};

/// Whether an `Entry` represents an `Employment` or `Project` record.
pub const EntryCategory = enum { Employment, Project };

/// Metadata pertaining to employment histories.
pub const EmploymentEntryData = struct {
    company: []const u8,
};

/// Metadata pertaining to projects.
pub const ProjectEntryData = struct {
    const Self = @This();

    brief: []const u8,
    image: []const u8,
    tags: []const []const u8,
    deployments: []const []const u8 = &.{},
    repositories: []const []const u8 = &.{},
};

/// Wrapper type to safely store metadata about employment or projects.
pub const EntryData = union(EntryCategory) {
    const Self = @This();

    Employment: EmploymentEntryData,
    Project: ProjectEntryData,
};

/// Stores data about an entry (some kind of record).
pub const Entry = struct {
    const Self = @This();

    title: []const u8,
    dates: DateRange,
    data: EntryData,
    text: []const u8,
};
