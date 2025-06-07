const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const makePackages = @import("./packages.zig").makePackages;
const binToLinkable = @import("./utils.zig").binToLinkable;
const Runtime = @import("./runtime.zig").Runtime;
const UpdateSnapshotHashStep = @import("./update_snapshot_hash.zig").UpdateSnapshotHashStep;

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "whether to statically or dynamically link the library") orelse @as(std.builtin.LinkMode, if (target.result.isGnuLibC()) .dynamic else .static);
    const sdk_hash = b.option([]const u8, "sdk-hash", "the sdk hash, must be a 10byte string") orelse "0000000000";
    const ship_dartdev = b.option(bool, "ship-dartdev", "whether to ship dartdev with the runtime") orelse true;

    const dart_host_exe = b.findProgram(&.{"dart"}, &.{}) catch |e| std.debug.panic("Cannot find dart: {s}", .{@errorName(e)});

    const dart_sdk_dep = b.dependency("dartsdk", .{});
    const update_snapshot_hash_step = UpdateSnapshotHashStep.create(
        b,
        dart_sdk_dep.path("."),
        b.path("runtime/vm/version.cc")
    );

    const host_runtime = Runtime.create(b, .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .precompiler = true,
        .exclude_cfe_and_kernel_platform = true,
        .update_snapshot_hash_step = update_snapshot_hash_step,
    });

    const dart_pkgs = makePackages(b);

    const dart_package_json_run = std.Build.Step.Run.create(b, "generate_package_config.dart");
    dart_package_json_run.addArgs(&.{
        dart_host_exe,
        "run",
        "tools/generate_package_config.dart",
    });
    dart_package_json_run.setCwd(dart_pkgs.getDirectory());

    _ = dart_pkgs.addCopyFile(b.path("tools/generate_package_config.dart"), "tools/generate_package_config.dart");

    const dart_frontend_compile_platform = std.Build.Step.Run.create(b, "compile_platform.dart");
    dart_frontend_compile_platform.step.dependOn(&dart_package_json_run.step);

    dart_frontend_compile_platform.addArgs(&.{
        dart_host_exe,
        b.fmt("-Dsdk_hash={s}", .{sdk_hash}),
        "run",
        "pkg/front_end/tool/compile_platform.dart"
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
        "vm_platform_strong.dill",
        "vm_outline_strong.dill",
    });

    const vm_platform_strong_dill = dart_pkgs.getDirectory().path(b, "vm_platform_strong.dill");

    dart_frontend_compile_platform.setCwd(dart_pkgs.getDirectory());

    const kernel_service_dill_compile = std.Build.Step.Run.create(b, "dartdev");
    kernel_service_dill_compile.step.dependOn(&dart_frontend_compile_platform.step);

    kernel_service_dill_compile.addArgs(&.{
        dart_host_exe,
        "run",
        "pkg/vm/bin/gen_kernel.dart",
        "--platform=vm_platform_strong.dill",
        "--no-aot",
        "--no-embed-sources",
        "-o",
        "kernel_service.dart.dill",
    });

    // const kernel_service_dill = kernel_service_dill_compile.addOutputFileArg("kernel_service.dart.dill");
    const kernel_service_dill = dart_pkgs.getDirectory().path(b, "kernel_service.dart.dill");

    kernel_service_dill_compile.addArgs(&.{
        b.fmt("-Dsdk_hash={s}", .{sdk_hash}),
        "--packages=org-dartlang-kernel-service:///.dart_tool/package_config.json",
        "--filesystem-root=.",
        "--filesystem-scheme=org-dartlang-kernel-service",
        "org-dartlang-kernel-service:///pkg/vm/bin/kernel_service.dart",
    });

    kernel_service_dill_compile.setCwd(dart_pkgs.getDirectory());

    const dart_snapshot_compile_wf = b.addWriteFiles();
    const dart_snapshot_compile = std.Build.Step.Run.create(b, "dart_snapshot_compile");
    dart_snapshot_compile.addArgs(&.{
        "./gen_snapshot"
    });

    dart_snapshot_compile.setCwd(dart_snapshot_compile_wf.getDirectory());

    _ = dart_snapshot_compile_wf.addCopyFile(host_runtime.gen_snapshot.getEmittedBin(), "gen_snapshot");

    dart_snapshot_compile.addArgs(&.{
        "--deterministic",
        "--snapshot_kind=core",
        "--vm_snapshot_data=vm_snapshot_data.bin",
        "--vm_snapshot_instructions=vm_snapshot_instructions.bin",
        "--isolate_snapshot_data=isolate_snapshot_data.bin",
        "--isolate_snapshot_instructions=isolate_snapshot_instructions.bin",
        "vm_platform_strong.dill",
    });

    _ = dart_snapshot_compile_wf.addCopyFile(vm_platform_strong_dill, "vm_platform_strong.dill");

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

    const dartdev_snapshot = std.Build.Step.Run.create(b, "dartdev");
    dartdev_snapshot.step.dependOn(&dart_frontend_compile_platform.step);
    dartdev_snapshot.step.dependOn(&dart_snapshot_compile.step);
    dartdev_snapshot.step.dependOn(&update_snapshot_hash_step.step);

    dartdev_snapshot.addArgs(&.{
        dart_host_exe,
        "run",
        "pkg/vm/bin/gen_kernel.dart",
        "--platform=vm_platform_strong.dill",
        "--no-aot",
        "--no-embed-sources",
        "--no-link-platform",
        "--output=dartdev.dart.snapshot",
        "pkg/dartdev/bin/dartdev.dart",
    });

    dartdev_snapshot.setCwd(dart_pkgs.getDirectory());

    // 创建输出快照文件的复制步骤
    const dartdev_snapshot_file = dart_pkgs.getDirectory().path(b, "dartdev.dart.snapshot");
    
    if (ship_dartdev){
        const install_dartdev_snapshot = b.addInstallFile(dartdev_snapshot_file, "bin/snapshots/dartdev.dart.snapshot");
        install_dartdev_snapshot.step.dependOn(&dartdev_snapshot.step);

        b.getInstallStep().dependOn(&install_dartdev_snapshot.step);
    }

    const runtime = Runtime.create(b, .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .precompiler = false,
        .exclude_cfe_and_kernel_platform = false,
        .snapshot_empty = false,
        .product = false,
        .update_snapshot_hash_step = update_snapshot_hash_step,
    });

    const kernel_service_dill_symbols = binToLinkable(b, kernel_service_dill, "kKernelServiceDill", target, optimize, .{
        .step = &kernel_service_dill_compile.step,
        .size_symbol = "kKernelServiceDillSize",
    });

    const vm_platform_strong_dill_symbols = binToLinkable(b, vm_platform_strong_dill, "kPlatformStrongDill", target, optimize, .{
        .step = &dart_frontend_compile_platform.step,
        .size_symbol = "kPlatformStrongDillSize",
    });

    runtime.gen_snapshot.addObject(vm_platform_strong_dill_symbols);
    runtime.gen_snapshot.addObject(kernel_service_dill_symbols);

    runtime.dart.addObject(vm_platform_strong_dill_symbols);
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
