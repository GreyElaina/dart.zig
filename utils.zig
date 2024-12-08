const std = @import("std");
const fs = std.fs;
const mem = std.mem;

pub fn collectSources(b: *std.Build, path: std.Build.LazyPath, variable: []const u8) []const []const u8 {
    const p = path.getPath(b);

    var file = fs.openFileAbsolute(p, .{}) catch |e| std.debug.panic("Failed to open {s}: {s}", .{ p, @errorName(e) });
    defer file.close();

    const metadata = file.metadata() catch |e| std.debug.panic("Failed to get metadata {s}: {s}", .{ p, @errorName(e) });

    const contents = file.readToEndAlloc(b.allocator, metadata.size()) catch |e| std.debug.panic("Failed to read {s}: {s}", .{ p, @errorName(e) });
    defer b.allocator.free(contents);

    var list = std.ArrayList([]const u8).init(b.allocator);
    defer list.deinit();

    const needle = b.fmt("{s} = [", .{variable});

    if (mem.indexOf(u8, contents, needle)) |i| {
        if (mem.indexOf(u8, contents[i..], "]")) |x| {
            const block = contents[(i + needle.len + 1)..(i + x)];

            if (mem.indexOf(u8, block, "\n") != null) {
                var it = mem.splitSequence(u8, block, "\n");

                while (it.next()) |line| {
                    const open_string = mem.indexOf(u8, line, "\"") orelse continue;
                    const close_string = mem.indexOf(u8, line[open_string..], "\",") orelse continue;
                    const string_value = line[(open_string + 1)..(close_string + open_string)];

                    if (mem.eql(u8, fs.path.extension(string_value), ".cc")) {
                        list.append(b.allocator.dupe(u8, string_value) catch @panic("OOM")) catch @panic("OOM");
                    }
                }
            } else {
                const open_string = mem.indexOf(u8, block, "\"") orelse @panic("No entry");
                const close_string = mem.indexOf(u8, block[(open_string + 1)..], "\"") orelse @panic("No entry");
                const string_value = block[(open_string + 1)..(close_string + open_string + 1)];

                if (mem.eql(u8, fs.path.extension(string_value), ".cc")) {
                    list.append(b.allocator.dupe(u8, string_value) catch @panic("OOM")) catch @panic("OOM");
                }
            }
        }
    }

    return list.toOwnedSlice() catch |e| std.debug.panic("Failed to allocate memory: {s}", .{@errorName(e)});
}

pub const BinToLinkableOptions = struct {
    size_symbol: ?[]const u8 = null,
    executable: bool = false,
    step: ?*std.Build.Step = null,
};

pub fn binToLinkable(
    b: *std.Build,
    file: std.Build.LazyPath,
    symbol_name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: BinToLinkableOptions,
) *std.Build.Step.Compile {
    const name = fs.path.basename(file.getDisplayName());
    const wf = b.addWriteFiles();

    _ = wf.addCopyFile(file, b.fmt("{s}.bin", .{name}));
    if (options.step) |step| wf.step.dependOn(step);

    var code = std.ArrayList(u8).init(b.allocator);
    defer code.deinit();

    code.appendSlice("comptime {\n") catch @panic("OOM");
    code.appendSlice(b.fmt("  @export({s}.ptr, .{{\n    .name = \"{s}\",\n", .{ symbol_name, symbol_name })) catch @panic("OOM");

    if (options.executable) {
        code.appendSlice("    .section = \"text\",\n") catch @panic("OOM");
    } else {
        code.appendSlice("    .section = \"rodata\",\n") catch @panic("OOM");
    }

    if (options.size_symbol) |size_symbol| {
        code.appendSlice(b.fmt("  }});\n  @export(&{s}.len, .{{ .name = \"{s}\"", .{ symbol_name, size_symbol })) catch @panic("OOM");
    }

    code.appendSlice("  });\n}\n\n") catch @panic("OOM");

    code.appendSlice(b.fmt("pub const {s} align(32) = @embedFile(\"{s}.bin\");", .{ symbol_name, name })) catch @panic("OOM");

    return b.addObject(.{
        .name = b.fmt("{s} {s}", .{ name, symbol_name }),
        .root_source_file = wf.add(b.fmt("{s}.zig", .{name}), code.items),
        .target = target,
        .optimize = optimize,
    });
}
