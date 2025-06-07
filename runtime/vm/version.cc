// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#include "vm/version.h"

#include "vm/globals.h"

namespace dart {

const char* Version::String() {
  return str_;
}

const char* Version::SnapshotString() {
  return snapshot_hash_;
}

const char* Version::CommitString() {
  return commit_;
}

const char* Version::SdkHash() {
  return git_short_hash_;
}

const char* Version::Channel() {
  return channel_;
}

const char* Version::snapshot_hash_ = "42f987b8c14084aea";
const char* Version::str_ =
    "3.8.1 (main) (Wed Jun 5 00:00:00 2025 +0000)"
    " on \"" kHostOperatingSystemName
    "_"
#if defined(USING_SIMULATOR)
    "sim"
#endif
    kTargetArchitectureName "\"";
const char* Version::commit_ = "3.8.1";
const char* Version::git_short_hash_ = "4bb26ad";
const char* Version::channel_ = "dev";

}  // namespace dart
