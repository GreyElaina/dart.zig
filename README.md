# dart.zig

修复了的 dartvm build.zig 构建脚本，包含一系列补丁集以修复一系列问题。

截止更新，已跟进至 3.9.0-209.0.dev 版本。

- 修复 MacOS 构建（zig 的 `uname` 实现有误）；
- 修复 dart 实现中包含的一个未初始化问题；
- 修复链接方式指定；
- 允许在编译时编译 dart cli 所需要的 `dartdev` 快照并交付；
- 将所使用的依赖 Zig Build System 的依赖项修复至可用；

目前仅有 MacOS 15.5 上使用 Zig 0.14.1 编译通过。

## 使用方法

首先最好保证你已经有一个可用的 Dart SDK，编译时运行一些 dart 脚本会用到。

```bash
# 获取源文件并应用补丁集
./scripts/patch_runtime_platform.sh
./scripts/patch_runtime_vm.sh

zig build
```

指定 `-Dlinkage=dynamic` 或 `-Dlinkage=static` 以确定链接方式，这将影响 `libdart.[dll/so/dylib]` 的生成；不特别指定的话，如果编译目标用 glibc 就默认 dynamic，否则 static。

指定 `-Dship_dartdev=[true/false]` 以确认是否交付 dartdev，以保证 dart 自带的 cli 可用；默认启用。

## 更新到指定 Dart 版本

执行以下指令以抓取 `$VERSION` 版本。

```bash
zig fetch --save=dartsdk https://dart.googlesource.com/sdk.git/+archive/refs/tags/$VERSION.tar.gz
```

完成后，可以通过编辑并执行 `scripts/update_deps.sh` 实现对 `build.zig.zon` 的更新。编辑需根据 Google 提供的 DEPS 文件。

此外，如果编译后发现提示 snapshot hash mismatch，可以根据提示编辑 `runtime/vm/version.cc`。