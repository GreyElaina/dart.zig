// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Generates the repo's ".dart_tool/package_config.json" file.
library;

import 'dart:convert';
import 'dart:io';

// Important! Do not add package: imports to this file.
// Do not add relative deps for libraries that themselves use package deps.
// This tool runs before the .dart_tool/package_config.json file is created, so
// can not itself use package references.

final repoRoot = dirname(dirname(fromUri(Platform.script)));

void main(List<String> args) {
  final fluteExists =
      Directory(join(repoRoot, platform('third_party/flute'))).existsSync();

  var excludedPackages = <String>[
    "pkg/observatory",
    "pkg/front_end/test"
  ];

  var packageDirs = [
    ...listSubdirectories(platform('pkg')),
    ...listSubdirectories(platform('third_party/pkg')),
    if (fluteExists) ...listSubdirectories(platform('third_party/flute')),
    platform('pkg/vm_service/test/test_package'),
    platform('runtime/observatory'),
    // platform('runtime/observatory/tests/service/observatory_test_package'),
    platform("pkg/front_end"),
    platform('runtime/tools/heapsnapshot'),
    platform('sdk/lib/_internal/sdk_library_metadata'),
    platform('third_party/devtools/devtools_shared'),
    platform('tools/package_deps'),
  ];

  packageDirs.removeWhere((path) {
    return excludedPackages.any((p) => path.startsWith(p));
  });

  var cfePackageDirs = <String>[
    // platform('pkg/front_end/testcases'),
  ];

  var feAnalyzerSharedPackageDirs = [
    platform('pkg/_fe_analyzer_shared/test/exhaustiveness/data'),
    platform('pkg/_fe_analyzer_shared/test/flow_analysis/assigned_variables'),
    platform('pkg/_fe_analyzer_shared/test/flow_analysis/definite_assignment'),
    platform(
        'pkg/_fe_analyzer_shared/test/flow_analysis/definite_unassignment'),
    platform('pkg/_fe_analyzer_shared/test/flow_analysis/nullability'),
    platform('pkg/_fe_analyzer_shared/test/flow_analysis/reachability'),
    platform('pkg/_fe_analyzer_shared/test/flow_analysis/type_promotion'),
    platform('pkg/_fe_analyzer_shared/test/flow_analysis/why_not_promoted'),
    platform('pkg/_fe_analyzer_shared/test/inheritance'),
  ];

  var frontendServerPackageDirs = [
    platform('pkg/frontend_server/test/fixtures'),
  ];

  var pkgVmPackageDirs = [
    platform('pkg/vm/testcases'),
  ];

  var sampleDirs = listSubdirectories(platform('samples')).toList();

  // Validate that all the given directories exist.
  var hasMissingDirectories = false;
  for (var path in [
    ...packageDirs,
    ...cfePackageDirs,
    ...feAnalyzerSharedPackageDirs,
    ...pkgVmPackageDirs,
    ...sampleDirs,
  ]) {
    if (!Directory(join(repoRoot, path)).existsSync()) {
      stderr.writeln("Unable to locate directory: '$path'.");
      hasMissingDirectories = true;
    }
  }

  if (hasMissingDirectories) {
    exit(1);
  }

  var packages = <Package>[
    ...makePackageConfigs(packageDirs),
    ...makeCfePackageConfigs(cfePackageDirs),
    ...makeFeAnalyzerSharedPackageConfigs(feAnalyzerSharedPackageDirs),
    ...makeFrontendServerPackageConfigs(frontendServerPackageDirs),
    ...makePkgVmPackageConfigs(pkgVmPackageDirs),
    ...makePackageConfigs(sampleDirs),
  ];
  packages.sort((a, b) => a.name.compareTo(b.name));

  // Remove specific packages.
  final packagesToRemove = {
    // If we're not using flute (i.e., this is a standard checkout), do not
    // include package:characters in the generated package config file. Contact
    // athom@ or ensure that license requirements are met before using this
    // dependency in other parts of the Dart SDK.
    if (!fluteExists) 'characters',
  };

  packages.removeWhere((p) {
    return packagesToRemove.contains(p.name);
  });

  // Check for duplicate packages - the same package sourced from multiple
  // repositories.
  final uniqueNames = packages.map((p) => p.name).toSet();

  var hasDuplicatePackages = false;

  for (var name in uniqueNames) {
    var matches = packages.where((p) => p.name == name).toList();
    if (matches.length > 1) {
      final inMonorepos = matches.where((p) => p.inMonorepo).toList();

      if (inMonorepos.length == 1) {
        // De-duplicating package 'name' - select just the monorepo version.
        packages.removeWhere((p) {
          return p.name == name && !p.inMonorepo;
        });
      } else {
        print('Duplicates found for package:$name');
        for (var package in matches) {
          print('  ${package.rootUri}');
        }

        hasDuplicatePackages = true;
      }
    }
  }

  if (hasDuplicatePackages) {
    exit(1);
  }

  var configFile = File(join(repoRoot, '.dart_tool', 'package_config.json'));
  var packageConfig = PackageConfig(
    packages,
    extraData: {
      'copyright': [
        'Copyright (c) 2020, the Dart project authors. Please see the AUTHORS ',
        'file for details. All rights reserved. Use of this source code is ',
        'governed by a BSD-style license that can be found in the LICENSE file.',
      ],
      'comment': [
        'Package configuration for all packages in pkg/ and third_party/pkg/',
      ],
    },
  );
  writeIfDifferent(configFile, packageConfig.generateJson('..'));
}

/// Writes the given [contents] string to [file] if the contents are different
/// than what's currently in the file.
///
/// This updates the file to the given contents, while preserving the file
/// timestamp if there are no changes.
void writeIfDifferent(File file, String contents) {
  if (!file.parent.existsSync()) {
    file.parent.createSync();
  }

  if (!file.existsSync() || file.readAsStringSync() != contents) {
    file.writeAsStringSync(contents);
  }
}

/// Generates package configurations for each package in [packageDirs].
Iterable<Package> makePackageConfigs(List<String> packageDirs) sync* {
  for (var packageDir in packageDirs) {
    var name = pubspecName(packageDir);

    if (name == null) {
      continue;
    }

    var version = pubspecLanguageVersion(packageDir);
    var hasLibDirectory =
        Directory(join(repoRoot, packageDir, 'lib')).existsSync();

    yield Package(
      name: name,
      rootUri: packageDir,
      packageUri: hasLibDirectory ? 'lib/' : null,
      languageVersion: version,
    );
  }
}

/// Generates package configurations for the special pseudo-packages.
Iterable<Package> makeSpecialPackageConfigs(
    String packageNamePrefix, List<String> packageDirs) sync* {
  // TODO: Remove the use of '.nonexisting/'.
  for (var packageDir in packageDirs) {
    yield Package(
      name: '${packageNamePrefix}_${basename(packageDir)}',
      rootUri: packageDir,
      packageUri: '.nonexisting/',
    );
  }
}

/// Generates package configurations for the special pseudo-packages used by the
/// CFE unit tests (`pkg/front_end/test/unit_test_suites.dart`).
Iterable<Package> makeCfePackageConfigs(List<String> packageDirs) =>
    makeSpecialPackageConfigs('front_end', packageDirs);

/// Generates package configurations for the special pseudo-packages used by the
/// _fe_analyzer_shared id tests.
Iterable<Package> makeFeAnalyzerSharedPackageConfigs(
        List<String> packageDirs) =>
    makeSpecialPackageConfigs('_fe_analyzer_shared', packageDirs);

/// Generates package configurations for the special pseudo-packages used by the
/// frontend_server tests.
Iterable<Package> makeFrontendServerPackageConfigs(List<String> packageDirs) =>
    makeSpecialPackageConfigs('frontend_server', packageDirs);

/// Generates package configurations for the special pseudo-packages used by the
/// pkg/vm unit tests (`pkg/vm/test`).
Iterable<Package> makePkgVmPackageConfigs(List<String> packageDirs) =>
    makeSpecialPackageConfigs('pkg_vm', packageDirs);

/// Finds the paths of the subdirectories of [parentPath] that contain pubspecs.
///
/// This method recurses until it finds a pubspec.yaml file.
Iterable<String> listSubdirectories(String parentPath) sync* {
  final parent = Directory(join(repoRoot, parentPath));

  for (var child in parent.listSync().whereType<Directory>()) {
    var name = basename(child.path);

    // Don't recurse into dot directories.
    if (name.startsWith('.')) continue;

    final pubspecFile = File(join(child.path, 'pubspec.yaml'));
    if (pubspecFile.existsSync() && !isWorkspacePubspec(pubspecFile)) {
      // Stop recursing when we find a pubspec file (and that pubspec does not
      // define a pub workspace).
      yield join(parentPath, name);
    } else {
      yield* listSubdirectories(join(parentPath, name));
    }
  }
}

final versionRE = RegExp(r"(?:\^|>=)(\d+\.\d+)");

/// Parses the package name in the pubspec for [packageDir].
String? pubspecName(String packageDir) {
  var pubspecFile = File(join(repoRoot, packageDir, 'pubspec.yaml'));

  if (!pubspecFile.existsSync()) {
    print('Error: Missing pubspec for $packageDir');
    exit(1);
  }

  var contents = pubspecFile.readAsLinesSync();
  if (!contents.any((line) => line.contains('name: '))) {
    print('Warning: Pubspec for $packageDir has no name.');
    // exit(1);
    // return basename(packageDir); // Fallback to directory name.
    return null;
  }

  var name = contents.firstWhere((line) => line.contains('name: '));
  return name.trim().substring('name:'.length).trim();
}

/// Returns whether the given pubspec defines a workspace.
bool isWorkspacePubspec(File pubspecFile) {
  if (!pubspecFile.existsSync()) {
    print('Error: Missing pubspec for ${pubspecFile.path}');
    exit(1);
  }

  var contents = pubspecFile.readAsLinesSync();
  return contents.any((line) => line.startsWith('workspace:'));
}

/// Infers the language version from the SDK constraint in the pubspec for
/// [packageDir].
///
/// The version is returned in the form `major.minor`.
String pubspecLanguageVersion(String packageDir) {
  var pubspecFile = File(join(repoRoot, packageDir, 'pubspec.yaml'));

  if (!pubspecFile.existsSync()) {
    print('Error: Missing pubspec for $packageDir');
    exit(1);
  }

  var contents = pubspecFile.readAsLinesSync();
  if (!contents.any((line) => line.contains('sdk: '))) {
    print('Error: Pubspec for $packageDir has no SDK constraint.');
    exit(1);
  }

  // Handle either "sdk: >=2.14.0 <3.0.0" or "sdk: ^2.3.0".
  var sdkConstraint = contents.firstWhere((line) => line.contains('sdk: '));
  sdkConstraint = sdkConstraint.trim().substring('sdk:'.length).trim();
  if (sdkConstraint.startsWith('"') || sdkConstraint.startsWith("'")) {
    sdkConstraint = sdkConstraint.substring(1, sdkConstraint.length - 2);
  }

  var match = versionRE.firstMatch(sdkConstraint);
  if (match == null) {
    print("Error: unknown version range for $packageDir: '$sdkConstraint'.");
    exit(1);
  }
  return match[1]!;
}

class Package {
  final String name;
  final String rootUri;
  final String? packageUri;
  final String? languageVersion;

  Package({
    required this.name,
    required this.rootUri,
    this.packageUri,
    this.languageVersion,
  });

  /// Whether this package lives in a monorepo.
  bool get inMonorepo {
    // By convention (and for our purposes), a monorepo package lives in a
    // `pkgs` directory.
    final paths = posix(rootUri).split('/');
    return paths.length >= 2 && paths[paths.length - 2] == 'pkgs';
  }

  Map<String, Object?> toMap(String relativeTo) {
    return {
      'name': name,
      'rootUri': posix(join(relativeTo, rootUri)),
      if (packageUri != null) 'packageUri': posix(packageUri!),
      if (languageVersion != null) 'languageVersion': languageVersion,
    };
  }
}

class PackageConfig {
  final List<Package> packages;
  final Map<String, Object?>? extraData;

  PackageConfig(this.packages, {this.extraData});

  String generateJson(String relativeTo) {
    var config = <String, Object?>{};
    if (extraData != null) {
      for (var key in extraData!.keys) {
        config[key] = extraData![key];
      }
    }
    config['configVersion'] = 2;
    config['generator'] = 'tools/generate_package_config.dart';
    config['packages'] =
        packages.map((package) => package.toMap(relativeTo)).toList();
    var jsonString = JsonEncoder.withIndent('  ').convert(config);
    return '$jsonString\n';
  }
}

// Below are some (very simplified) versions of the package:path functions.

final String _separator = Platform.pathSeparator;

String dirname(String s) {
  return s.substring(0, s.lastIndexOf(_separator));
}

String join(String s1, String s2, [String? s3]) {
  if (s3 != null) {
    return join(join(s1, s2), s3);
  } else {
    return s1.endsWith(_separator) ? '$s1$s2' : '$s1$_separator$s2';
  }
}

String basename(String s) {
  while (s.endsWith(_separator)) {
    s = s.substring(0, s.length - 1);
  }
  return s.substring(s.lastIndexOf(_separator) + 1);
}

String fromUri(Uri uri) => uri.toFilePath();

/// Given a platform path, return a posix one.
String posix(String s) =>
    Platform.isWindows ? s.replaceAll(_separator, '/') : s;

/// Given a posix path, return a platform one.
String platform(String s) =>
    Platform.isWindows ? s.replaceAll('/', _separator) : s;
