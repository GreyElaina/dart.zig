const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const crypto = std.crypto;

const VM_SNAPSHOT_FILES = [_][]const u8{
    // Header files
    "app_snapshot.h",
    "datastream.h",
    "image_snapshot.h",
    "object.h",
    "raw_object.h",
    "snapshot.h",
    "symbols.h",
    // Source files
    "app_snapshot.cc",
    "dart.cc",
    "dart_api_impl.cc",
    "image_snapshot.cc",
    "object.cc",
    "raw_object.cc",
    "snapshot.cc",
    "symbols.cc",
};

pub fn makeSnapshotHashString(allocator: std.mem.Allocator, dart_sdk_path: []const u8) ![]u8 {
    var hasher = crypto.hash.Md5.init(.{});

    for (VM_SNAPSHOT_FILES) |filename| {
        const file_path = try fs.path.join(allocator, &.{ dart_sdk_path, "runtime", "vm", filename });
        defer allocator.free(file_path);

        const file = fs.openFileAbsolute(file_path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                std.log.warn("VM snapshot file not found: {s}", .{file_path});
                continue;
            },
            else => return err,
        };
        defer file.close();

        const file_contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(file_contents);

        hasher.update(file_contents);
    }

    var hash_bytes: [16]u8 = undefined;
    hasher.final(&hash_bytes);

    // Convert to hex string
    const hash_string = try allocator.alloc(u8, 32);
    _ = try fmt.bufPrint(hash_string, "{}", .{fmt.fmtSliceHexLower(&hash_bytes)});

    return hash_string;
}

pub fn updateVersionFile(allocator: std.mem.Allocator, version_file_path: []const u8, new_hash: []const u8) !void {
    const file = try fs.openFileAbsolute(version_file_path, .{ .mode = .read_write });
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(contents);

    // Find and replace the snapshot_hash_ line
    const needle = "const char* Version::snapshot_hash_ = \"";
    const start_pos = std.mem.indexOf(u8, contents, needle) orelse return error.HashLineNotFound;

    const value_start = start_pos + needle.len;
    const quote_pos = std.mem.indexOfScalarPos(u8, contents, value_start, '"') orelse return error.ClosingQuoteNotFound;

    // Create new content by replacing the hash value
    const new_contents = try fmt.allocPrint(allocator, "{s}{s}{s}", .{
        contents[0..value_start],
        new_hash,
        contents[quote_pos..],
    });
    defer allocator.free(new_contents);

    // Write back to file
    try file.seekTo(0);
    try file.setEndPos(0);
    try file.writeAll(new_contents);
}

pub const UpdateSnapshotHashStep = struct {
    step: std.Build.Step,
    dart_sdk_path: std.Build.LazyPath,
    version_file_path: std.Build.LazyPath,

    pub fn create(b: *std.Build, dart_sdk_path: std.Build.LazyPath, version_file_path: std.Build.LazyPath) *UpdateSnapshotHashStep {
        const self = b.allocator.create(UpdateSnapshotHashStep) catch @panic("OOM");
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "update version.cc",
                .owner = b,
                .makeFn = make,
            }),
            .dart_sdk_path = dart_sdk_path,
            .version_file_path = version_file_path,
        };
        return self;
    }

    fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
        _ = options;
        const self: *UpdateSnapshotHashStep = @fieldParentPtr("step", step);
        const b = step.owner;

        const dart_sdk_path_str = self.dart_sdk_path.getPath(b);
        const version_file_path_str = self.version_file_path.getPath(b);

        const hash = try makeSnapshotHashString(b.allocator, dart_sdk_path_str);
        defer b.allocator.free(hash);

        // Take first 15 characters to match the existing format
        const truncated_hash = hash[0..@min(15, hash.len)];

        try updateVersionFile(b.allocator, version_file_path_str, truncated_hash);

        std.log.info("Updated version.cc with snapshot hash: {s}", .{truncated_hash});
    }
};
