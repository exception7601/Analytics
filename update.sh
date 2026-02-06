#!/bin/bash

set -e

ROOT_DIR="$(pwd)"
REPO="firebase/firebase-ios-sdk"
MY_REPO="exception7601/Analytics"
VERSION=$(gh release list --repo $REPO --exclude-pre-releases --limit 1 --json tagName -q '.[0].tagName')
if git rev-parse "${VERSION}" >/dev/null 2>&1; then
  echo "Version ${VERSION} already exists. No update needed."
  exit 0
fi
OUTPUT_DIR="$(pwd)/.output"
FB_DIR="$OUTPUT_DIR/Firebase"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "Latest Firebase Version: $VERSION"

curl -LO "https://github.com/$REPO/releases/download/$VERSION/Firebase.zip"
unzip -qo Firebase.zip -d "$OUTPUT_DIR"
rm Firebase.zip

BINARY_TARGETS=""
ZIPS=()

package() {
  local name=$1
  local zip_path="$OUTPUT_DIR/$name.zip"
  echo "Packaging $name..."

  find "$name" -name "*.xcframework" -type d | while read -r xc; do
    find "$xc" -maxdepth 1 -mindepth 1 -type d ! -name "*ios*" -exec rm -rf {} +
    find "$xc" -maxdepth 1 -mindepth 1 -type d -name "*maccatalyst*" -exec rm -rf {} +
  done

  (cd "$name" && zip -r "$zip_path" .)

  local sum
  sum=$(sha256sum "$zip_path")
  sum=${sum%% *}

  [ -n "$BINARY_TARGETS" ] && BINARY_TARGETS+=",\\n\\n"
  BINARY_TARGETS+=".binaryTarget(
    name: \"$name\",
    url: \"https://github.com/$MY_REPO/releases/download/$VERSION/$name.zip\",
    checksum: \"$sum\"
)"
  ZIPS+=("$zip_path")
}

cd "$FB_DIR"

cp "module.modulemap" "FirebaseAnalytics/"
cp "Firebase.h" "FirebaseAnalytics/"

package "FirebaseAnalytics"
package "FirebaseRemoteConfig"

cd "$ROOT_DIR"

RELEASE_NOTES="SPM binaryTargets

\`\`\`swift
$BINARY_TARGETS
\`\`\`"

BUILD=$(date +%s)
echo "$VERSION.$BUILD" >version

git add version
git commit -m "v$VERSION"

git tag -a "$VERSION" -m "v$VERSION"
git push origin HEAD --tags

echo "Creating release $VERSION..."
gh release create "$VERSION" "${ZIPS[@]}" --notes "$(echo -e "$RELEASE_NOTES")"

echo "Done."
