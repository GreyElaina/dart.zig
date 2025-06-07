const std = @import("std");
const Compile = std.Build.Step.Compile;
const collectSources = @import("./utils.zig").collectSources;
const UpdateSnapshotHashStep = @import("./update_snapshot_hash.zig").UpdateSnapshotHashStep;

pub const Runtime = struct {
    step: std.Build.Step,
    libdart_lib: *Compile,
    libdart_platform: *Compile,
    libdart_vm: *Compile,
    libdart_compiler: *Compile,
    libdart_builtin: *Compile,
    libdart: *Compile,
    elf_loader: *Compile,
    native_assets: *Compile,
    gen_snapshot_dart_io: *Compile,
    gen_snapshot: *Compile,
    dart: *Compile,
    update_snapshot_hash_step: *UpdateSnapshotHashStep,

    pub const Options = struct {
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
        linkage: std.builtin.LinkMode,
        precompiler: bool = false,
        exclude_cfe_and_kernel_platform: bool = false,
        dynamic_modules: bool = true,
        product: bool = false,
        include_suffix: bool = false,
        snapshot_empty: bool = false,
        update_snapshot_hash_step: *UpdateSnapshotHashStep,
    };

    pub fn create(b: *std.Build, options: Options) *Runtime {
        const self = b.allocator.create(Runtime) catch @panic("OOM");

        var cflags = std.ArrayList([]const u8).init(b.allocator);

        cflags.append(b.fmt("-DDART_HOST_OS_{s}", .{
            std.ascii.allocUpperString(b.allocator, @tagName(options.target.result.os.tag)) catch @panic("OOM"),
        })) catch @panic("OOM");

        cflags.append(b.fmt("-DTARGET_ARCH_{s}", .{
            switch (options.target.result.cpu.arch) {
                .aarch64 => "ARM64",
                else => |v| std.ascii.allocUpperString(b.allocator, @tagName(v)) catch @panic("OOM"),
            },
        })) catch @panic("OOM");

        if (options.precompiler) {
            cflags.append("-DDART_PRECOMPILER=1") catch @panic("OOM");
        }

        if (options.exclude_cfe_and_kernel_platform) {
            cflags.append("-DEXCLUDE_CFE_AND_KERNEL_PLATFORM=1") catch @panic("OOM");
        }

        if (options.dynamic_modules) {
            cflags.append("-DDART_DYNAMIC_MODULES=1") catch @panic("OOM");
        }

        if (options.product) {
            cflags.append("-DPRODUCT=1") catch @panic("OOM");
        }

        const suffix = blk: {
            var parts = std.ArrayList(u8).init(b.allocator);

            if (options.precompiler) parts.appendSlice("_precompiler") catch @panic("OOM");

            parts.appendSlice(if (options.include_suffix) (if (options.product) "_product" else switch (options.optimize) {
                .Debug => "_debug",
                .ReleaseSafe => "_relsafe",
                .ReleaseFast => "_relfast",
                .ReleaseSmall => "_relsml",
            }) else "") catch @panic("OOM");

            break :blk parts.items;
        };

        const dart_sdk_dep = b.dependency("dartsdk", .{});

        // Use the provided version update step
        const update_snapshot_hash_step = options.update_snapshot_hash_step;

        const icu = b.dependency("icu", .{
            .target = options.target,
            .optimize = options.optimize,
            .linkage = .static,
        });

        const zlib = b.dependency("zlib", .{
            .target = options.target,
            .optimize = options.optimize,
            .linkage = .static,
        });

        const boringssl = b.dependency("boringssl", .{
            .target = options.target,
            .optimize = options.optimize,
            .linkage = .static,
        });

        const dart_headers = b.addWriteFiles();
        for (zlib.artifact("z").installed_headers.items) |header| {
            _ = dart_headers.addCopyFile(header.file.source, b.fmt("zlib/{s}", .{header.file.dest_rel_path}));
        }

        const double_conversion = b.addStaticLibrary(.{
            .name = "double-conversion",
            .target = options.target,
            .optimize = options.optimize,
        });

        double_conversion.addCSourceFiles(.{
            .root = dart_sdk_dep.path("third_party/double-conversion/src"),
            .files = collectSources(b, dart_sdk_dep.path("third_party/double-conversion/src/BUILD.gn"), "sources"),
            .flags = cflags.items,
        });

        double_conversion.linkLibCpp();

        const libdart_lib = b.addStaticLibrary(.{
            .name = b.fmt("dart-lib{s}", .{suffix}),
            .target = options.target,
            .optimize = options.optimize,
        });

        libdart_lib.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/lib"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/lib/async_sources.gni"), "async_runtime_cc_files"),
            .flags = cflags.items,
        });

        libdart_lib.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/lib"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/lib/concurrent_sources.gni"), "concurrent_runtime_cc_files"),
            .flags = cflags.items,
        });

        libdart_lib.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/lib"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/lib/core_sources.gni"), "core_runtime_cc_files"),
            .flags = cflags.items,
        });

        libdart_lib.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/lib"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/lib/developer_sources.gni"), "developer_runtime_cc_files"),
            .flags = cflags.items,
        });

        libdart_lib.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/lib"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/lib/ffi_sources.gni"), "ffi_runtime_cc_files"),
            .flags = cflags.items,
        });

        libdart_lib.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/lib"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/lib/isolate_sources.gni"), "isolate_runtime_cc_files"),
            .flags = cflags.items,
        });

        libdart_lib.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/lib"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/lib/math_sources.gni"), "math_runtime_cc_files"),
            .flags = cflags.items,
        });

        libdart_lib.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/lib"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/lib/mirrors_sources.gni"), "mirrors_runtime_cc_files"),
            .flags = cflags.items,
        });

        libdart_lib.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/lib"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/lib/typed_data_sources.gni"), "typed_data_runtime_cc_files"),
            .flags = cflags.items,
        });

        libdart_lib.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/lib"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/lib/vmservice_sources.gni"), "vmservice_runtime_cc_files"),
            .flags = cflags.items,
        });

        libdart_lib.addCSourceFile(.{
            .file = dart_sdk_dep.path("runtime/vm/bootstrap.cc"),
            .flags = cflags.items,
        });

        libdart_lib.addIncludePath(dart_sdk_dep.path("runtime"));
        libdart_lib.linkLibCpp();

        const libdart_platform = b.addStaticLibrary(.{
            .name = b.fmt("dart-platform{s}", .{suffix}),
            .target = options.target,
            .optimize = options.optimize,
        });

        libdart_platform.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/platform"),
            .files = blk: {
                const all_files = collectSources(b, dart_sdk_dep.path("runtime/platform/platform_sources.gni"), "platform_sources");
                var filtered = std.ArrayList([]const u8).init(b.allocator);

                for (all_files) |file| {
                    if (!std.mem.eql(u8, file, "utils_macos.cc")) {
                        filtered.append(file) catch @panic("OOM");
                    }
                }
                break :blk filtered.toOwnedSlice() catch @panic("OOM");
            },
            .flags = cflags.items,
        });

        libdart_platform.addCSourceFile(.{
            .file = b.path("runtime/platform/utils_macos.cc"),
            .flags = cflags.items,
        });

        libdart_platform.addCSourceFile(.{
            .file = dart_sdk_dep.path("runtime/platform/no_tsan.cc"),
            .flags = cflags.items,
        });

        libdart_platform.addIncludePath(dart_sdk_dep.path("runtime"));
        libdart_platform.linkLibCpp();

        const libdart_vm = b.addStaticLibrary(.{
            .name = b.fmt("dart-vm{s}", .{suffix}),
            .target = options.target,
            .optimize = options.optimize,
        });

        libdart_vm.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/vm"),
            // .files = collectSources(b, dart_sdk_dep.path("runtime/vm/vm_sources.gni"), "vm_sources"),
            .files = blk: {
                const all_files = collectSources(b, dart_sdk_dep.path("runtime/vm/vm_sources.gni"), "vm_sources");
                var filtered = std.ArrayList([]const u8).init(b.allocator);
                for (all_files) |file| {
                    if (!std.mem.eql(u8, file, "isolate.cc")) {
                        filtered.append(file) catch @panic("OOM");
                    }
                }
                break :blk filtered.toOwnedSlice() catch @panic("OOM");
            },
            .flags = cflags.items,
        });

        libdart_vm.addCSourceFile(.{
            .file = b.path("runtime/vm/isolate.cc"),
            .flags = cflags.items,
        });

        libdart_vm.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/vm/compiler"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/vm/compiler/compiler_sources.gni"), "compiler_api_sources"),
            .flags = cflags.items,
        });

        libdart_vm.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/vm/compiler"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/vm/compiler/compiler_sources.gni"), "disassembler_sources"),
            .flags = cflags.items,
        });

        libdart_vm.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/vm/ffi"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/vm/ffi/ffi_sources.gni"), "ffi_sources"),
            .flags = cflags.items,
        });

        libdart_vm.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/vm/heap"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/vm/heap/heap_sources.gni"), "heap_sources"),
            .flags = cflags.items,
        });

        libdart_vm.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/vm/regexp"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/vm/regexp/regexp_sources.gni"), "regexp_sources"),
            .flags = cflags.items,
        });

        libdart_vm.addIncludePath(dart_sdk_dep.path("runtime"));

        libdart_vm.linkLibrary(boringssl.artifact("crypto"));
        libdart_vm.linkLibrary(icu.artifact("icui18n"));
        libdart_vm.linkLibrary(icu.artifact("icuuc"));
        libdart_vm.linkLibCpp();

        const libdart_compiler = b.addStaticLibrary(.{
            .name = b.fmt("dart-compiler{s}", .{suffix}),
            .target = options.target,
            .optimize = options.optimize,
        });

        libdart_compiler.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/vm/compiler"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/vm/compiler/compiler_sources.gni"), "compiler_sources"),
            .flags = cflags.items,
        });

        libdart_compiler.addIncludePath(dart_sdk_dep.path("runtime"));
        libdart_compiler.linkLibCpp();

        const libdart_builtin = b.addStaticLibrary(.{
            .name = b.fmt("dart-builtin{s}", .{suffix}),
            .target = options.target,
            .optimize = options.optimize,
        });

        libdart_builtin.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/bin"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/bin/builtin_impl_sources.gni"), "builtin_impl_sources"),
            .flags = cflags.items,
        });

        libdart_builtin.addIncludePath(dart_sdk_dep.path("runtime"));
        libdart_builtin.linkLibCpp();

        // const libdart = b.addStaticLibrary(.{
        // .name = b.fmt("dart{s}", .{suffix}),
        // .target = options.target,
        // .optimize = options.optimize,
        // });
        // libdart.linkLibCpp();

        const libdart = if (options.linkage == .dynamic) blk: {
            // Build as a shared library if dynamic linkage is requested
            const shared_lib = b.addSharedLibrary(.{
                .name = b.fmt("dart{s}", .{suffix}),
                .target = options.target,
                .optimize = options.optimize,
            });
            shared_lib.linkLibCpp();
            break :blk shared_lib;
        } else blk: {
            // Build as a static library otherwise
            const static_lib = b.addStaticLibrary(.{
                .name = b.fmt("dart{s}", .{suffix}),
                .target = options.target,
                .optimize = options.optimize,
            });
            static_lib.linkLibCpp();
            break :blk static_lib;
        };

        libdart.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/vm"),
            .files = &.{
                "analyze_snapshot_api_impl.cc",
                "dart_api_impl.cc",
                "native_api_impl.cc",
            },
            .flags = cflags.items,
        });

        libdart.addCSourceFile(.{
            .file = b.path("runtime/vm/version.cc"),
            .flags = cflags.items,
        });

        // Make sure version file is updated before compiling libdart
        libdart.step.dependOn(&update_snapshot_hash_step.step);

        libdart.addIncludePath(dart_sdk_dep.path("runtime"));

        libdart.linkLibrary(double_conversion);
        libdart.linkLibrary(libdart_lib);
        libdart.linkLibrary(libdart_compiler);
        libdart.linkLibrary(libdart_platform);
        libdart.linkLibrary(libdart_vm);
        // libdart.linkLibrary(libdart_builtin);

        const native_assets = b.addStaticLibrary(.{
            .name = b.fmt("native-assets{s}", .{suffix}),
            .target = options.target,
            .optimize = options.optimize,
        });

        native_assets.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/bin"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/bin/native_assets_impl_sources.gni"), "native_assets_impl_sources"),
            .flags = cflags.items,
        });

        native_assets.addIncludePath(dart_sdk_dep.path("runtime"));
        native_assets.linkLibCpp();

        const elf_loader = b.addStaticLibrary(.{
            .name = b.fmt("elf-loader{s}", .{suffix}),
            .target = options.target,
            .optimize = options.optimize,
        });

        elf_loader.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/bin"),
            .files = &.{
                "elf_loader.cc",
                "virtual_memory_fuchsia.cc",
                "virtual_memory_posix.cc",
                "virtual_memory_win.cc",
            },
            .flags = cflags.items,
        });

        elf_loader.addIncludePath(dart_sdk_dep.path("runtime"));
        elf_loader.linkLibCpp();

        const gen_snapshot_dart_io = b.addStaticLibrary(.{
            .name = b.fmt("gen-snapshot-dart-io{s}", .{suffix}),
            .target = options.target,
            .optimize = options.optimize,
        });

        gen_snapshot_dart_io.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/bin"),
            .files = &.{
                "io_natives.cc",
            },
            .flags = cflags.items,
        });

        gen_snapshot_dart_io.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/bin"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/bin/io_impl_sources.gni"), "io_impl_sources"),
            .flags = cflags.items,
        });

        gen_snapshot_dart_io.addCSourceFiles(.{
            .root = dart_sdk_dep.path("third_party/fallback_root_certificates"),
            .files = &.{
                "root_certificates.cc",
            },
            .flags = cflags.items,
        });

        gen_snapshot_dart_io.addIncludePath(dart_sdk_dep.path("runtime"));
        gen_snapshot_dart_io.addIncludePath(.{
            .generated = .{ .file = &dart_headers.generated_directory },
        });

        gen_snapshot_dart_io.linkLibrary(zlib.artifact("z"));
        gen_snapshot_dart_io.linkLibrary(boringssl.artifact("crypto"));
        gen_snapshot_dart_io.linkLibrary(boringssl.artifact("ssl"));
        gen_snapshot_dart_io.linkLibCpp();

        // Link macOS system frameworks for dart
        if (options.target.result.os.tag == .macos) {
            gen_snapshot_dart_io.linkFramework("CoreFoundation");
            gen_snapshot_dart_io.linkFramework("Foundation");
            gen_snapshot_dart_io.linkFramework("Security");
            gen_snapshot_dart_io.linkFramework("CoreServices");

            var macos_cflags = std.ArrayList([]const u8).init(b.allocator);
            macos_cflags.appendSlice(cflags.items) catch @panic("OOM");
            macos_cflags.append("-fobjc-arc") catch @panic("OOM");

            gen_snapshot_dart_io.addCSourceFiles(.{
                .root = dart_sdk_dep.path("runtime/bin"),
                .files = &.{
                    "platform_macos_cocoa.mm",
                },
                .flags = macos_cflags.items,
            });
        }

        const gen_snapshot = b.addExecutable(.{
            .name = b.fmt("gen_snapshot{s}", .{suffix}),
            .target = options.target,
            .optimize = options.optimize,
        });

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
            .flags = cflags.items,
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

        // Link macOS system frameworks for dart
        if (options.target.result.os.tag == .macos) {
            gen_snapshot.linkFramework("CoreFoundation");
            gen_snapshot.linkFramework("Foundation");
            gen_snapshot.linkFramework("Security");
            gen_snapshot.linkFramework("CoreServices");
        }

        const dart = b.addExecutable(.{
            .name = b.fmt("dart{s}", .{suffix}),
            .target = options.target,
            .optimize = options.optimize,
            .linkage = if (options.target.result.os.tag == .macos) .dynamic else options.linkage,
        });

        dart.addCSourceFiles(.{
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
                "snapshot_utils.cc",
                "vmservice_impl.cc",
            },
            .flags = cflags.items,
        });

        if (options.snapshot_empty) {
            dart.addCSourceFile(.{
                .file = dart_sdk_dep.path("runtime/bin/snapshot_empty.cc"),
                .flags = cflags.items,
            });
        }

        dart.addCSourceFiles(.{
            .root = dart_sdk_dep.path("runtime/bin"),
            .files = collectSources(b, dart_sdk_dep.path("runtime/bin/io_impl_sources.gni"), "io_impl_sources"),
            .flags = cflags.items,
        });

        dart.addCSourceFiles(.{
            .root = dart_sdk_dep.path("third_party/fallback_root_certificates"),
            .files = &.{
                "root_certificates.cc",
            },
            .flags = cflags.items,
        });

        dart.addIncludePath(dart_sdk_dep.path("runtime"));
        dart.addIncludePath(.{
            .generated = .{ .file = &dart_headers.generated_directory },
        });

        dart.linkLibrary(boringssl.artifact("crypto"));
        dart.linkLibrary(boringssl.artifact("ssl"));
        dart.linkLibrary(zlib.artifact("z"));
        dart.linkLibrary(icu.artifact("icui18n"));
        dart.linkLibrary(icu.artifact("icuuc"));
        dart.linkLibrary(native_assets);
        dart.linkLibrary(libdart_builtin);
        dart.linkLibrary(libdart_platform);
        dart.linkLibrary(libdart);

        // Link macOS system frameworks for dart
        if (options.target.result.os.tag == .macos) {
            dart.linkFramework("CoreFoundation");
            dart.linkFramework("Foundation");
            dart.linkFramework("Security");
            dart.linkFramework("CoreServices");

            var macos_cflags = std.ArrayList([]const u8).init(b.allocator);
            macos_cflags.appendSlice(cflags.items) catch @panic("OOM");
            macos_cflags.append("-fobjc-arc") catch @panic("OOM");

            dart.addCSourceFiles(.{
                .root = dart_sdk_dep.path("runtime/bin"),
                .files = &.{
                    "platform_macos_cocoa.mm",
                },
                .flags = macos_cflags.items,
            });
        }

        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "dart runtime",
                .owner = b,
            }),
            .libdart_lib = libdart_lib,
            .libdart_platform = libdart_platform,
            .libdart_vm = libdart_vm,
            .libdart_compiler = libdart_compiler,
            .libdart_builtin = libdart_builtin,
            .libdart = libdart,
            .elf_loader = elf_loader,
            .native_assets = native_assets,
            .gen_snapshot_dart_io = gen_snapshot_dart_io,
            .gen_snapshot = gen_snapshot,
            .dart = dart,
            .update_snapshot_hash_step = update_snapshot_hash_step,
        };

        self.step.dependOn(&self.libdart.step);
        self.step.dependOn(&self.gen_snapshot.step);
        self.step.dependOn(&self.dart.step);
        return self;
    }

    pub fn install(self: *Runtime) void {
        self.step.owner.installArtifact(self.gen_snapshot);
        self.step.owner.installArtifact(self.libdart);
        self.step.owner.installArtifact(self.dart);
    }
};
