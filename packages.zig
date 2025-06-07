const std = @import("std");

pub fn makePackages(b: *std.Build) *std.Build.Step.WriteFile {
    const pkgs = b.addWriteFiles();

    const dart_sdk_dep = b.dependency("dartsdk", .{});
    const dart_devtools = b.dependency("dart-devtools", .{});
    const dart_core = b.dependency("dart-core", .{});

    const dart_package_config = b.dependency("dart-package_config", .{});
    const dart_pub_semver = b.dependency("dart-pub_semver", .{});
    const dart_yaml = b.dependency("dart-yaml", .{});
    const dart_source_span = b.dependency("dart-source_span", .{});
    const dart_term_glyph = b.dependency("dart-term_glyph", .{});
    const dart_string_scanner = b.dependency("dart-string_scanner", .{});
    const dart_source_maps = b.dependency("dart-source_maps", .{});
    const dart_stream_channel = b.dependency("dart-stream_channel", .{});
    const dart_shelf = b.dependency("dart-shelf", .{});
    const dart_web_socket_channel = b.dependency("dart-web_socket_channel", .{});
    const dart_http_parser = b.dependency("dart-http_parser", .{});
    const dart_stack_trace = b.dependency("dart-stack_trace", .{});
    const dart_http = b.dependency("dart-http", .{});
    const dart_tools = b.dependency("dart-tools", .{});
    const dart_yaml_edit = b.dependency("dart-yaml_edit", .{});
    const dart_sse = b.dependency("dart-sse", .{});
    const dart_watcher = b.dependency("dart-watcher", .{});
    const dart_web_inspection_protocol = b.dependency("dart-web_inspection_protocol", .{});
    const dart_dartdoc = b.dependency("dart-dartdoc", .{});
    const dart_http_multi_server = b.dependency("dart-http_multi_server", .{});
    const dart_native = b.dependency("dart-native", .{});
    const dart_pub = b.dependency("dart-pub", .{});
    const dart_markdown = b.dependency("dart-markdown", .{});
    const dart_glob = b.dependency("dart-glob", .{});
    const dart_dart_style = b.dependency("dart-dart_style", .{});
    const dart_tar = b.dependency("dart-tar", .{});
    const dart_webdev = b.dependency("dart-webdev", .{});
    const dart_pool = b.dependency("dart-pool", .{});
    const dart_leak_tracker = b.dependency("dart-leak_tracker", .{});

    _ = pkgs.addCopyDirectory(dart_sdk_dep.path("pkg"), "pkg", .{});
    _ = pkgs.addCopyDirectory(dart_sdk_dep.path("third_party/pkg"), "third_party/pkg", .{});
    _ = pkgs.addCopyDirectory(dart_sdk_dep.path("runtime/observatory"), "runtime/observatory", .{});
    _ = pkgs.addCopyDirectory(dart_sdk_dep.path("runtime/tools/heapsnapshot"), "runtime/tools/heapsnapshot", .{});
    _ = pkgs.addCopyDirectory(dart_sdk_dep.path("sdk/lib"), "sdk/lib", .{});
    _ = pkgs.addCopyDirectory(dart_sdk_dep.path("tools/package_deps"), "tools/package_deps", .{});
    _ = pkgs.addCopyDirectory(dart_sdk_dep.path("samples"), "samples", .{});
    _ = pkgs.addCopyDirectory(dart_sdk_dep.path("utils"), "utils", .{});
    _ = pkgs.addCopyDirectory(dart_devtools.path("packages/devtools_shared"), "third_party/devtools/devtools_shared", .{});

    _ = pkgs.addCopyDirectory(dart_core.path("pkgs"), "third_party/pkg", .{});
    _ = pkgs.addCopyDirectory(dart_package_config.path("."), "third_party/pkg/package_config", .{});
    _ = pkgs.addCopyDirectory(dart_pub_semver.path("."), "third_party/pkg/pub_semver", .{});
    _ = pkgs.addCopyDirectory(dart_yaml.path("."), "third_party/pkg/yaml", .{});
    _ = pkgs.addCopyDirectory(dart_source_span.path("."), "third_party/pkg/source_span", .{});
    _ = pkgs.addCopyDirectory(dart_term_glyph.path("."), "third_party/pkg/term_glyph", .{});
    _ = pkgs.addCopyDirectory(dart_string_scanner.path("."), "third_party/pkg/string_scanner", .{});
    _ = pkgs.addCopyDirectory(dart_source_maps.path("."), "third_party/pkg/source_maps", .{});
    _ = pkgs.addCopyDirectory(dart_stream_channel.path("."), "third_party/pkg/stream_channel", .{});
    _ = pkgs.addCopyDirectory(dart_shelf.path("."), "third_party/pkg/shelf", .{});
    _ = pkgs.addCopyDirectory(dart_web_socket_channel.path("."), "third_party/pkg/web_socket_channel", .{});
    _ = pkgs.addCopyDirectory(dart_http_parser.path("."), "third_party/pkg/http_parser", .{});
    _ = pkgs.addCopyDirectory(dart_stack_trace.path("."), "third_party/pkg/stack_trace", .{});
    _ = pkgs.addCopyDirectory(dart_http.path("."), "third_party/pkg/http", .{});
    _ = pkgs.addCopyDirectory(dart_tools.path("."), "third_party/pkg/tools", .{});
    _ = pkgs.addCopyDirectory(dart_yaml_edit.path("."), "third_party/pkg/yaml_edit", .{});
    _ = pkgs.addCopyDirectory(dart_sse.path("."), "third_party/pkg/sse", .{});
    _ = pkgs.addCopyDirectory(dart_watcher.path("."), "third_party/pkg/watcher", .{});
    _ = pkgs.addCopyDirectory(dart_web_inspection_protocol.path("."), "third_party/pkg/web_inspection_protocol", .{});
    _ = pkgs.addCopyDirectory(dart_dartdoc.path("."), "third_party/pkg/dartdoc", .{});
    _ = pkgs.addCopyDirectory(dart_http_multi_server.path("."), "third_party/pkg/http_multi_server", .{});
    _ = pkgs.addCopyDirectory(dart_native.path("."), "third_party/pkg/native", .{});
    _ = pkgs.addCopyDirectory(dart_pub.path("."), "third_party/pkg/pub", .{});
    _ = pkgs.addCopyDirectory(dart_markdown.path("."), "third_party/pkg/markdown", .{});
    _ = pkgs.addCopyDirectory(dart_glob.path("."), "third_party/pkg/glob", .{});
    _ = pkgs.addCopyDirectory(dart_dart_style.path("."), "third_party/pkg/dart_style", .{});
    _ = pkgs.addCopyDirectory(dart_tar.path("."), "third_party/pkg/tar", .{});
    _ = pkgs.addCopyDirectory(dart_webdev.path("."), "third_party/pkg/webdev", .{});
    _ = pkgs.addCopyDirectory(dart_pool.path("."), "third_party/pkg/pool", .{});
    _ = pkgs.addCopyDirectory(dart_leak_tracker.path("."), "third_party/pkg/leak_tracker", .{});

    return pkgs;
}
