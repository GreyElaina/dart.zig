const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const makePackages = @import("./packages.zig").makePackages;
const binToLinkable = @import("./utils.zig").binToLinkable;
const Runtime = @import("./runtime.zig").Runtime;

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const linkage = b.option(std.builtin.LinkMode, "linkage", "whether to statically or dynamically link the library") orelse @as(std.builtin.LinkMode, if (target.result.isGnuLibC()) .dynamic else .static);
    const use_compiled_gen_snapshot = b.option(bool, "use-compiled-gen-snapshot", "whether to use the gen_snapshot provided by the host or build one") orelse false;
    const sdk_hash = b.option([]const u8, "sdk-hash", "the sdk hash") orelse "0000000000";

    const dart_host_exe = b.findProgram(&.{"dart"}, &.{}) catch |e| std.debug.panic("Cannot find dart: {s}", .{@errorName(e)});

    const gen_snapshot_host_exe = b.pathJoin(&.{
        fs.path.dirname(dart_host_exe) orelse @panic("Failed to get the dirname"),
        "utils",
        "gen_snapshot",
    });

    const host_runtime = Runtime.create(b, .{
        .target = b.host,
        .optimize = optimize,
        .linkage = linkage,
        .precompiler = true,
        .exclude_cfe_and_kernel_platform = true,
    });

    const dart_pkgs = makePackages(b);

    const dart_package_json_run = std.Build.Step.Run.create(b, "generate_package_config.dart");
    dart_package_json_run.addArgs(&.{
        dart_host_exe,
        "run",
    });

    dart_package_json_run.addFileArg(dart_pkgs.addCopyFile(b.path("tools/generate_package_config.dart"), "tools/generate_package_config.dart"));
    dart_package_json_run.setCwd(dart_pkgs.getDirectory());

    const dart_frontend_compile_platform = std.Build.Step.Run.create(b, "compile_platform.dart");
    dart_frontend_compile_platform.step.dependOn(&dart_package_json_run.step);

    dart_frontend_compile_platform.addArgs(&.{
        dart_host_exe,
        b.fmt("-Dsdk_hash={s}", .{sdk_hash}),
        "run",
    });

    dart_frontend_compile_platform.addFileArg(.{
        .generated = .{
            .file = &dart_pkgs.generated_directory,
            .sub_path = "pkg/front_end/tool/compile_platform.dart",
        },
    });

    dart_frontend_compile_platform.addArgs(&.{
        "dart:core",
        "--single-root-scheme=org-dartlang-sdk",
        "--single-root-base=.",
        "-Ddart.vm.product=false",
        "-Ddart.isVM=true",
        "--nnbd-strong",
        "org-dartlang-sdk:///sdk/lib/libraries.json",
        "vm_outline_strong.dill",
    });

    const vm_platform_strong_dill = dart_frontend_compile_platform.addOutputFileArg("vm_platform_strong.dill");

    dart_frontend_compile_platform.addArg("vm_outline_strong.dill");

    dart_frontend_compile_platform.setCwd(dart_pkgs.getDirectory());

    const kernel_service_dill_compile = std.Build.Step.Run.create(b, "dartdev");
    kernel_service_dill_compile.step.dependOn(&dart_frontend_compile_platform.step);

    kernel_service_dill_compile.addArgs(&.{
        dart_host_exe,
        "run",
    });

    kernel_service_dill_compile.addFileArg(.{
        .generated = .{
            .file = &dart_pkgs.generated_directory,
            .sub_path = "pkg/vm/bin/gen_kernel.dart",
        },
    });

    kernel_service_dill_compile.addPrefixedFileArg("--platform=", vm_platform_strong_dill);

    kernel_service_dill_compile.addArgs(&.{
        "--no-aot",
        "--no-embed-sources",
        "-o",
    });

    const kernel_service_dill = kernel_service_dill_compile.addOutputFileArg("kernel_service.dart.dill");

    kernel_service_dill_compile.addArgs(&.{
        b.fmt("-Dsdk_hash={s}", .{sdk_hash}),
        "--packages=org-dartlang-kernel-service:///.dart_tool/package_config.json",
        "--filesystem-root=.",
        "--filesystem-scheme=org-dartlang-kernel-service",
        "org-dartlang-kernel-service:///pkg/vm/bin/kernel_service.dart",
    });

    kernel_service_dill_compile.setCwd(dart_pkgs.getDirectory());

    const dart_snapshot_compile = if (use_compiled_gen_snapshot) b.addRunArtifact(host_runtime.gen_snapshot) else b.addSystemCommand(&.{
        gen_snapshot_host_exe,
    });

    const dart_snapshot_compile_wf = b.addWriteFiles();
    dart_snapshot_compile.setCwd(dart_snapshot_compile_wf.getDirectory());

    dart_snapshot_compile.addArgs(&.{
        "--deterministic",
        "--snapshot_kind=core",
        "--vm_snapshot_data=vm_snapshot_data.bin",
        "--vm_snapshot_instructions=vm_snapshot_instructions.bin",
        "--isolate_snapshot_data=isolate_snapshot_data.bin",
        "--isolate_snapshot_instructions=isolate_snapshot_instructions.bin",
    });

    const vm_snapshot_data = std.Build.LazyPath{
        .generated = .{
            .file = &dart_snapshot_compile_wf.generated_directory,
            .sub_path = "vm_snapshot_data.bin",
        },
    };

    const vm_snapshot_instructions = std.Build.LazyPath{
        .generated = .{
            .file = &dart_snapshot_compile_wf.generated_directory,
            .sub_path = "vm_snapshot_instructions.bin",
        },
    };

    const isolate_snapshot_data = std.Build.LazyPath{
        .generated = .{
            .file = &dart_snapshot_compile_wf.generated_directory,
            .sub_path = "isolate_snapshot_data.bin",
        },
    };

    const isolate_snapshot_instructions = std.Build.LazyPath{
        .generated = .{
            .file = &dart_snapshot_compile_wf.generated_directory,
            .sub_path = "isolate_snapshot_instructions.bin",
        },
    };

    dart_snapshot_compile.addFileArg(vm_platform_strong_dill);

    const dartdev_snapshot = std.Build.Step.Run.create(b, "dartdev");
    dartdev_snapshot.step.dependOn(&dart_frontend_compile_platform.step);

    dartdev_snapshot.addArgs(&.{
        dart_host_exe,
        "run",
    });

    dartdev_snapshot.addFileArg(.{
        .generated = .{
            .file = &dart_pkgs.generated_directory,
            .sub_path = "pkg/vm/bin/gen_kernel.dart",
        },
    });

    dartdev_snapshot.addArgs(&.{
        "--platform=vm_platform_strong.dill",
        "--no-aot",
        "--no-embed-sources",
        "--no-link-platform",
        "--output=dartdev.dart.snapshot",
    });

    dartdev_snapshot.addFileArg(.{
        .generated = .{
            .file = &dart_pkgs.generated_directory,
            .sub_path = "pkg/dartdev/bin/dartdev.dart",
        },
    });

    dartdev_snapshot.setCwd(dart_pkgs.getDirectory());

    const runtime = Runtime.create(b, .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .precompiler = false,
        .exclude_cfe_and_kernel_platform = false,
        .snapshot_empty = false,
    });

    const vm_platform_strong_dill_symbols = binToLinkable(b, vm_platform_strong_dill, "kPlatformStrongDill", target, optimize, .{
        .size_symbol = "kPlatformStrongDillSize",
    });

    runtime.gen_snapshot.addObject(vm_platform_strong_dill_symbols);
    runtime.dart.addObject(vm_platform_strong_dill_symbols);

    const kernel_service_dill_symbols = binToLinkable(b, kernel_service_dill, "kKernelServiceDill", target, optimize, .{
        .size_symbol = "kKernelServiceDillSize",
    });

    runtime.gen_snapshot.addObject(kernel_service_dill_symbols);
    runtime.dart.addObject(kernel_service_dill_symbols);

    runtime.dart.addObject(binToLinkable(b, vm_snapshot_data, "kDartVmSnapshotData", target, optimize, .{
        .step = &dart_snapshot_compile.step,
    }));
    runtime.dart.addObject(binToLinkable(b, vm_snapshot_instructions, "kDartVmSnapshotInstructions", target, optimize, .{
        .step = &dart_snapshot_compile.step,
        .executable = true,
    }));

    runtime.dart.addObject(binToLinkable(b, isolate_snapshot_data, "kDartCoreIsolateSnapshotData", target, optimize, .{
        .step = &dart_snapshot_compile.step,
    }));
    runtime.dart.addObject(binToLinkable(b, isolate_snapshot_instructions, "kDartCoreIsolateSnapshotInstructions", target, optimize, .{
        .step = &dart_snapshot_compile.step,
        .executable = true,
    }));

    runtime.install();
}
