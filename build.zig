const std = @import("std");
const mem = std.mem;
const fs = std.fs;

fn collectSources(b: *std.Build, path: std.Build.LazyPath, variable: []const u8) []const []const u8 {
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

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const linkage = b.option(std.builtin.LinkMode, "linkage", "whether to statically or dynamically link the library") orelse @as(std.builtin.LinkMode, if (target.result.isGnuLibC()) .dynamic else .static);

    const dart_sdk_dep = b.dependency("dart-sdk", .{});

    const icu = b.dependency("icu", .{
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });

    const zlib = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });

    const boringssl = b.dependency("boringssl", .{
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });

    const dart_headers = b.addWriteFiles();
    for (zlib.artifact("z").installed_headers.items) |header| {
        _ = dart_headers.addCopyFile(header.file.source, b.fmt("zlib/{s}", .{header.file.dest_rel_path}));
    }

    const dart_cflags: []const []const u8 = &.{
        b.fmt("-DDART_HOST_OS_{s}", .{
            std.ascii.allocUpperString(b.allocator, @tagName(target.result.os.tag)) catch @panic("OOM"),
        }),
        b.fmt("-DTARGET_ARCH_{s}", .{
            switch (target.result.cpu.arch) {
                .aarch64 => "ARM64",
                else => |v| std.ascii.allocUpperString(b.allocator, @tagName(v)) catch @panic("OOM"),
            },
        }),
        "-DDART_PRECOMPILER",
        "-DEXCLUDE_CFE_AND_KERNEL_PLATFORM",
    };

    const double_conversion = b.addStaticLibrary(.{
        .name = "double-conversion",
        .target = target,
        .optimize = optimize,
    });

    double_conversion.addCSourceFiles(.{
        .root = dart_sdk_dep.path("third_party/double-conversion/src"),
        .files = collectSources(b, dart_sdk_dep.path("third_party/double-conversion/src/BUILD.gn"), "sources"),
        .flags = dart_cflags,
    });

    double_conversion.linkLibCpp();

    const libdart_lib = b.addStaticLibrary(.{
        .name = "dart-lib",
        .target = target,
        .optimize = optimize,
    });

    libdart_lib.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/lib"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/lib/async_sources.gni"), "async_runtime_cc_files"),
        .flags = dart_cflags,
    });

    libdart_lib.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/lib"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/lib/concurrent_sources.gni"), "concurrent_runtime_cc_files"),
        .flags = dart_cflags,
    });

    libdart_lib.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/lib"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/lib/core_sources.gni"), "core_runtime_cc_files"),
        .flags = dart_cflags,
    });

    libdart_lib.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/lib"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/lib/developer_sources.gni"), "developer_runtime_cc_files"),
        .flags = dart_cflags,
    });

    libdart_lib.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/lib"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/lib/ffi_sources.gni"), "ffi_runtime_cc_files"),
        .flags = dart_cflags,
    });

    libdart_lib.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/lib"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/lib/isolate_sources.gni"), "isolate_runtime_cc_files"),
        .flags = dart_cflags,
    });

    libdart_lib.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/lib"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/lib/math_sources.gni"), "math_runtime_cc_files"),
        .flags = dart_cflags,
    });

    libdart_lib.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/lib"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/lib/mirrors_sources.gni"), "mirrors_runtime_cc_files"),
        .flags = dart_cflags,
    });

    libdart_lib.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/lib"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/lib/typed_data_sources.gni"), "typed_data_runtime_cc_files"),
        .flags = dart_cflags,
    });

    libdart_lib.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/lib"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/lib/vmservice_sources.gni"), "vmservice_runtime_cc_files"),
        .flags = dart_cflags,
    });

    libdart_lib.addCSourceFile(.{
        .file = dart_sdk_dep.path("runtime/vm/bootstrap.cc"),
        .flags = dart_cflags,
    });

    libdart_lib.addIncludePath(dart_sdk_dep.path("runtime"));
    libdart_lib.linkLibCpp();

    const libdart_platform = b.addStaticLibrary(.{
        .name = "dart-platform",
        .target = target,
        .optimize = optimize,
    });

    libdart_platform.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/platform"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/platform/platform_sources.gni"), "platform_sources"),
        .flags = dart_cflags,
    });

    libdart_platform.addCSourceFile(.{
        .file = dart_sdk_dep.path("runtime/platform/no_tsan.cc"),
        .flags = dart_cflags,
    });

    libdart_platform.addIncludePath(dart_sdk_dep.path("runtime"));
    libdart_platform.linkLibCpp();

    const libdart_vm = b.addStaticLibrary(.{
        .name = "dart-vm",
        .target = target,
        .optimize = optimize,
    });

    libdart_vm.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/vm"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/vm/vm_sources.gni"), "vm_sources"),
        .flags = dart_cflags,
    });

    libdart_vm.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/vm/compiler"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/vm/compiler/compiler_sources.gni"), "compiler_api_sources"),
        .flags = dart_cflags,
    });

    libdart_vm.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/vm/compiler"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/vm/compiler/compiler_sources.gni"), "disassembler_sources"),
        .flags = dart_cflags,
    });

    libdart_vm.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/vm/ffi"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/vm/ffi/ffi_sources.gni"), "ffi_sources"),
        .flags = dart_cflags,
    });

    libdart_vm.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/vm/heap"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/vm/heap/heap_sources.gni"), "heap_sources"),
        .flags = dart_cflags,
    });

    libdart_vm.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/vm/regexp"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/vm/regexp/regexp_sources.gni"), "regexp_sources"),
        .flags = dart_cflags,
    });

    libdart_vm.addIncludePath(dart_sdk_dep.path("runtime"));

    libdart_vm.linkLibrary(icu.artifact("icui18n"));
    libdart_vm.linkLibrary(icu.artifact("icuuc"));
    libdart_vm.linkLibCpp();

    const libdart_compiler = b.addStaticLibrary(.{
        .name = "dart-compiler",
        .target = target,
        .optimize = optimize,
    });

    libdart_compiler.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/vm/compiler"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/vm/compiler/compiler_sources.gni"), "compiler_sources"),
        .flags = dart_cflags,
    });

    libdart_compiler.addIncludePath(dart_sdk_dep.path("runtime"));
    libdart_compiler.linkLibCpp();

    const libdart = std.Build.Step.Compile.create(b, .{
        .name = "dart",
        .root_module = .{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        },
        .kind = .lib,
        .linkage = linkage,
    });

    libdart.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/vm"),
        .files = &.{
            "analyze_snapshot_api_impl.cc",
            "dart_api_impl.cc",
            "native_api_impl.cc",
        },
        .flags = dart_cflags,
    });

    libdart.addCSourceFile(.{
        .file = b.path("runtime/vm/version.cc"),
        .flags = dart_cflags,
    });

    libdart.addIncludePath(dart_sdk_dep.path("runtime"));

    libdart.linkLibrary(double_conversion);
    libdart.linkLibrary(libdart_lib);
    libdart.linkLibrary(libdart_compiler);
    libdart.linkLibrary(libdart_platform);
    libdart.linkLibrary(libdart_vm);

    b.installArtifact(libdart);

    const libdart_builtin = b.addStaticLibrary(.{
        .name = "dart-builtin",
        .target = target,
        .optimize = optimize,
    });

    libdart_builtin.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/bin"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/bin/builtin_impl_sources.gni"), "builtin_impl_sources"),
        .flags = dart_cflags,
    });

    libdart_builtin.addIncludePath(dart_sdk_dep.path("runtime"));
    libdart_builtin.linkLibCpp();

    const native_assets = b.addStaticLibrary(.{
        .name = "native-assets",
        .target = target,
        .optimize = optimize,
    });

    native_assets.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/bin"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/bin/native_assets_impl_sources.gni"), "native_assets_impl_sources"),
        .flags = dart_cflags,
    });

    native_assets.addIncludePath(dart_sdk_dep.path("runtime"));
    native_assets.linkLibCpp();

    const elf_loader = b.addStaticLibrary(.{
        .name = "elf-loader",
        .target = target,
        .optimize = optimize,
    });

    elf_loader.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/bin"),
        .files = &.{
            "elf_loader.cc",
            "virtual_memory_fuchsia.cc",
            "virtual_memory_posix.cc",
            "virtual_memory_win.cc",
        },
        .flags = dart_cflags,
    });

    elf_loader.addIncludePath(dart_sdk_dep.path("runtime"));
    elf_loader.linkLibCpp();

    const gen_snapshot_dart_io = b.addStaticLibrary(.{
        .name = "gen-snapshot-dart-io",
        .target = target,
        .optimize = optimize,
    });

    gen_snapshot_dart_io.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/bin"),
        .files = &.{
            "io_natives.cc",
        },
        .flags = dart_cflags,
    });

    gen_snapshot_dart_io.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/bin"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/bin/io_impl_sources.gni"), "io_impl_sources"),
        .flags = dart_cflags,
    });

    gen_snapshot_dart_io.addCSourceFiles(.{
        .root = dart_sdk_dep.path("third_party/fallback_root_certificates"),
        .files = &.{
            "root_certificates.cc",
        },
        .flags = dart_cflags,
    });

    gen_snapshot_dart_io.addIncludePath(dart_sdk_dep.path("runtime"));
    gen_snapshot_dart_io.addIncludePath(.{
        .generated = .{ .file = &dart_headers.generated_directory },
    });

    gen_snapshot_dart_io.linkLibrary(zlib.artifact("z"));
    gen_snapshot_dart_io.linkLibrary(boringssl.artifact("crypto"));
    gen_snapshot_dart_io.linkLibrary(boringssl.artifact("ssl"));
    gen_snapshot_dart_io.linkLibCpp();

    const gen_snapshot = b.addExecutable(.{
        .name = "gen_snapshot",
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });

    gen_snapshot.root_module.addCMacro("EXCLUDE_CFE_AND_KERNEL_PLATFORM", "1");

    gen_snapshot.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/bin"),
        .files = &.{
            "builtin.cc",
            "error_exit.cc",
            "gzip.cc",
            "loader.cc",
            "snapshot_utils.cc",
            "builtin_gen_snapshot.cc",
            "dfe.cc",
            "gen_snapshot.cc",
            "options.cc",
            "vmservice_impl.cc",
        },
        .flags = dart_cflags,
    });

    gen_snapshot.addIncludePath(dart_sdk_dep.path("runtime"));
    gen_snapshot.addIncludePath(.{
        .generated = .{ .file = &dart_headers.generated_directory },
    });

    gen_snapshot.linkLibrary(zlib.artifact("z"));
    gen_snapshot.linkLibrary(libdart_builtin);
    gen_snapshot.linkLibrary(libdart_platform);
    gen_snapshot.linkLibrary(libdart);
    gen_snapshot.linkLibrary(gen_snapshot_dart_io);

    b.installArtifact(gen_snapshot);

    const dart_exe = b.addExecutable(.{
        .name = "dart",
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });

    dart_exe.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/bin"),
        .files = &.{
            "builtin.cc",
            "builtin_natives.cc",
            "crashpad.cc",
            "dart_embedder_api_impl.cc",
            "dartdev_isolate.cc",
            "dfe.cc",
            "error_exit.cc",
            "gzip.cc",
            "icu.cc",
            "io_natives.cc",
            "loader.cc",
            "main.cc",
            "main_impl.cc",
            "main_options.cc",
            "options.cc",
            "observatory_assets_empty.cc",
            "snapshot_empty.cc",
            "snapshot_utils.cc",
            "vmservice_impl.cc",
        },
        .flags = dart_cflags,
    });

    dart_exe.addCSourceFiles(.{
        .root = dart_sdk_dep.path("runtime/bin"),
        .files = collectSources(b, dart_sdk_dep.path("runtime/bin/io_impl_sources.gni"), "io_impl_sources"),
        .flags = dart_cflags,
    });

    dart_exe.addCSourceFiles(.{
        .root = dart_sdk_dep.path("third_party/fallback_root_certificates"),
        .files = &.{
            "root_certificates.cc",
        },
        .flags = dart_cflags,
    });

    dart_exe.addIncludePath(dart_sdk_dep.path("runtime"));
    dart_exe.addIncludePath(.{
        .generated = .{ .file = &dart_headers.generated_directory },
    });

    dart_exe.linkLibrary(boringssl.artifact("crypto"));
    dart_exe.linkLibrary(boringssl.artifact("ssl"));
    dart_exe.linkLibrary(zlib.artifact("z"));
    dart_exe.linkLibrary(icu.artifact("icui18n"));
    dart_exe.linkLibrary(icu.artifact("icuuc"));
    dart_exe.linkLibrary(native_assets);
    dart_exe.linkLibrary(libdart_builtin);
    dart_exe.linkLibrary(libdart_platform);
    dart_exe.linkLibrary(libdart);

    b.installArtifact(dart_exe);
}
