BASE_URL=https://dart.googlesource.com/sdk.git/+/refs/tags
VERSION=3.9.0-209.0.dev
BLOB=runtime/platform/utils_macos.cc
SAVE=runtime/platform/utils_macos.cc
PATCH=runtime/platform/utils_macos_cc_check_min_version.patch

if [ -f "$SAVE" ]; then
    echo "Skipping download, $SAVE already exists."
    exit 0
fi

curl -L "$BASE_URL/$VERSION/$BLOB?format=TEXT" | base64 -d > $SAVE
patch -p1 < $PATCH
