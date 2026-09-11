#!/bin/zsh
set -euo pipefail

# Build a Release .app and zip it the way Finder/Gatekeeper expect
# (ditto preserves macOS metadata that `zip` would drop).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED="${DERIVED_DATA_PATH:-$ROOT/.derivedData}"
DIST="${DIST_PATH:-$ROOT/dist}"
PRODUCT_NAME="Simple Scroll Reverser"
ZIP_NAME="${ZIP_NAME:-SimpleScrollReverser.zip}"

echo "==> Building ${PRODUCT_NAME} (${CONFIGURATION})"
xcodebuild \
  -project SimpleScrollReverser.xcodeproj \
  -scheme SimpleScrollReverser \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" \
  -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY='-' \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  ENABLE_HARDENED_RUNTIME=NO \
  DEVELOPMENT_TEAM= \
  OTHER_CODE_SIGN_FLAGS='--identifier=com.ajju2004srivatsan.simplescrollreverser' \
  build

APP="$DERIVED/Build/Products/${CONFIGURATION}/${PRODUCT_NAME}.app"
if [[ ! -d "$APP" ]]; then
  echo "error: expected app at $APP" >&2
  find "$DERIVED/Build/Products" -name '*.app' -print >&2 || true
  exit 1
fi

echo "==> Ad-hoc signing"
codesign --force --deep --sign - \
  --identifier com.ajju2004srivatsan.simplescrollreverser \
  --timestamp=none \
  "$APP"
codesign --verify --verbose=2 "$APP" || true

mkdir -p "$DIST"
ZIP="$DIST/$ZIP_NAME"
rm -f "$ZIP"
echo "==> Zipping to $ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Done"
ls -lh "$APP" "$ZIP"
