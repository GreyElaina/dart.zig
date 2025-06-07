#!/bin/bash

# Dart.zig 依赖更新脚本
# 基于 Dart SDK DEPS 文件自动更新 build.zig.zon 中的依赖版本和hash
# 使用 zig fetch 命令获取最新的依赖hash值

set -e  # 遇到错误立即退出

echo "开始更新 Dart.zig 依赖..."

# 检查是否存在 zig 命令
if ! command -v zig &> /dev/null; then
    echo "错误: 未找到 zig 命令，请确保已安装 Zig 编译器"
    exit 1
fi

# 检查是否存在 build.zig.zon 文件
if [ ! -f "build.zig.zon" ]; then
    echo "错误: 未找到 build.zig.zon 文件，请在项目根目录下运行此脚本"
    exit 1
fi

# 备份原始文件
cp build.zig.zon build.zig.zon.backup
echo "已备份原始 build.zig.zon 文件为 build.zig.zon.backup"

echo "正在更新依赖版本..."

# DEPS 文件中指定的版本和提交哈希
DEVTOOLS_REV="c65f3f2e353750614b66c664d4dd451853d1035e"
CORE_REV="635dfa32c261ba078438b74de397f2207904ca78"
DART_STYLE_REV="100db45075abdd66fd8788b205243e90ff0595df"
DARTDOC_REV="4ceea6b8240bf1dd9694a170368264e40c67d66b"
HTTP_REV="e70a41b8b841ada9ba124b3b9e1a4d3c525b8bf9"
LEAK_TRACKER_REV="f5620600a5ce1c44f65ddaa02001e200b096e14c"
NATIVE_REV="7f5bfa6973becbb0b4d6ecc34f41f9cdc5701d83"
PUB_REV="818f10b4bf9249bd0b2c212dd8709675eeb14cd2"
SHELF_REV="082d3ac2d13a98700d8148e8fad8f3e12a6fd0e1"
TAR_REV="5a1ea943e70cdf3fa5e1102cdbb9418bd9b4b81a"
TOOLS_REV="e84cbd9e1b111d80763ae8b3e04685bd66866f08"
WEBDEV_REV="55941b0ce5a2eb8a5799ee39f675b40c116f268d"
WEBKIT_INSPECTION_REV="effa75205516757795683d527c3dea9546eb0c32"

# 对于 boringssl、icu 和 zlib，直接使用含有 build.zig 的仓库。

# 默认使用 elaina-archive
BORINGSSL_REPO=https://github.com/elaina-archive/boringssl.zig
ICU_REPO=https://github.com/elaina-archive/icu.zig
ZLIB_REPO=https://github.com/elaina-archive/zlib.zig

BORINGSSL_REV="a934ee9e1fe4397e682f9f18b1f4f061d7400f9d"
ICU_REV="43953f57b037778a1b8005564afabe214834f7bd"
ZLIB_REV="108fa50cda23ed4a712a098d058dccbbfd248206"

echo "更新 dartsdk 到版本: $SDK_REV"
# zig fetch --save=dartsdk "https://dart.googlesource.com/sdk.git/+archive/$SDK_REV.tar.gz"

# DevTools (对应 devtools_rev)
echo "更新 dart-devtools 到版本: $DEVTOOLS_REV"
zig fetch --save=dart-devtools "https://github.com/flutter/devtools/archive/$DEVTOOLS_REV.tar.gz"

# Dart Core 包 (对应 core_rev)
echo "更新 dart-core 到版本: $CORE_REV"
zig fetch --save=dart-core "https://github.com/dart-lang/core/archive/$CORE_REV.tar.gz"

# Dart Style (对应 dart_style_rev)
echo "更新 dart-dart_style 到版本: $DART_STYLE_REV"
zig fetch --save=dart-dart_style "https://github.com/dart-lang/dart_style/archive/$DART_STYLE_REV.tar.gz"

# DartDoc (对应 dartdoc_rev)
echo "更新 dart-dartdoc 到版本: $DARTDOC_REV"
zig fetch --save=dart-dartdoc "https://github.com/dart-lang/dartdoc/archive/$DARTDOC_REV.tar.gz"

# HTTP 包 (对应 http_rev)
echo "更新 dart-http 到版本: $HTTP_REV"
zig fetch --save=dart-http "https://github.com/dart-lang/http/archive/$HTTP_REV.tar.gz"

# Leak Tracker (对应 leak_tracker_rev)
echo "更新 dart-leak_tracker 到版本: $LEAK_TRACKER_REV"
zig fetch --save=dart-leak_tracker "https://github.com/dart-lang/leak_tracker/archive/$LEAK_TRACKER_REV.tar.gz"

# Native 包 (对应 native_rev)
echo "更新 dart-native 到版本: $NATIVE_REV"
zig fetch --save=dart-native "https://github.com/dart-lang/native/archive/$NATIVE_REV.tar.gz"

# Pub 包 (对应 pub_rev)
echo "更新 dart-pub 到版本: $PUB_REV"
zig fetch --save=dart-pub "https://github.com/dart-lang/pub/archive/$PUB_REV.tar.gz"

# Shelf 包 (对应 shelf_rev)
echo "更新 dart-shelf 到版本: $SHELF_REV"
zig fetch --save=dart-shelf "https://github.com/dart-lang/shelf/archive/$SHELF_REV.tar.gz"

# Tar 包 (对应 tar_rev)
echo "更新 dart-tar 到版本: $TAR_REV"
zig fetch --save=dart-tar "https://github.com/simolus3/tar/archive/$TAR_REV.tar.gz"

# Tools 包 (对应 tools_rev)
echo "更新 dart-tools 到版本: $TOOLS_REV"
zig fetch --save=dart-tools "https://github.com/dart-lang/tools/archive/$TOOLS_REV.tar.gz"

# WebDev 包 (对应 webdev_rev)
echo "更新 dart-webdev 到版本: $WEBDEV_REV"
zig fetch --save=dart-webdev "https://github.com/dart-lang/webdev/archive/$WEBDEV_REV.tar.gz"

# WebKit Inspection Protocol (对应 webkit_inspection_protocol_rev)
echo "更新 dart-web_inspection_protocol 到版本: $WEBKIT_INSPECTION_REV"
zig fetch --save=dart-web_inspection_protocol "https://github.com/google/webkit_inspection_protocol.dart/archive/$WEBKIT_INSPECTION_REV.tar.gz"

# 更新第三方库依赖
echo "正在更新第三方库依赖..."

# BoringSSL (对应 boringssl_rev)
echo "更新 boringssl 依赖..."
# 注意：这里需要使用包装后的 zig 版本
zig fetch --save "git+$BORINGSSL_REPO?ref=HEAD"

# ICU (对应 icu_rev)
echo "更新 icu 依赖..."
zig fetch --save "git+$ICU_REPO?ref=HEAD"

# Zlib (对应 zlib_rev)
echo "更新 zlib 依赖..."
zig fetch --save "git+$ZLIB_REPO?ref=HEAD"

echo ""
echo "依赖更新完成！"
echo ""
echo "更新摘要:"
echo "- Dart SDK: $SDK_REV"
echo "- DevTools: $DEVTOOLS_REV" 
echo "- Core: $CORE_REV"
echo "- Dart Style: $DART_STYLE_REV"
echo "- DartDoc: $DARTDOC_REV"
echo "- HTTP: $HTTP_REV"
echo "- Leak Tracker: $LEAK_TRACKER_REV"
echo "- Native: $NATIVE_REV"
echo "- Pub: $PUB_REV"
echo "- Shelf: $SHELF_REV"
echo "- Tar: $TAR_REV"
echo "- Tools: $TOOLS_REV"
echo "- WebDev: $WEBDEV_REV"
echo "- WebKit Inspection: $WEBKIT_INSPECTION_REV"
echo "- BoringSSL: $BORINGSSL_REV"
echo "- ICU: $ICU_REV"
echo "- Zlib: $ZLIB_REV"
echo ""
echo "备份文件保存在: build.zig.zon.backup"
echo ""
echo "建议运行 'zig build' 验证依赖更新是否成功"

# 可选：自动运行构建验证
read -p "是否立即运行 'zig build' 验证依赖更新？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "正在验证构建..."
    if zig build; then
        echo "✅ 构建成功！依赖更新验证通过"
    else
        echo "❌ 构建失败！请检查依赖配置"
        echo "可以使用 'cp build.zig.zon.backup build.zig.zon' 恢复备份"
        exit 1
    fi
fi

echo "脚本执行完成！"
