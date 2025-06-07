BASE_URL=https://dart.googlesource.com/sdk.git/+/refs/tags
VERSION=3.9.0-209.0.dev
BLOB=runtime/vm/isolate.cc
SAVE=runtime/vm/isolate.cc
PATCH=runtime/vm/uninit_has_attempted_stepping.patch

if [ -f "$SAVE" ]; then
    echo "Skipping download, $SAVE already exists."
    exit 0
fi

curl -L "$BASE_URL/$VERSION/$BLOB?format=TEXT" | base64 -d > $SAVE
patch -p1 < $PATCH
