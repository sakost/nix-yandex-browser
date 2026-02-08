#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"
PACKAGES_URL="http://repo.yandex.ru/yandex-browser/deb/dists/stable/main/binary-amd64/Packages"

# Fetch latest version from the Yandex apt repository
echo "Fetching package index from $PACKAGES_URL ..."
LATEST_VERSION=$(curl -sL "$PACKAGES_URL" \
  | awk '/^Package: yandex-browser-stable$/,/^$/' \
  | awk '/^Version:/ { print $2; exit }')

if [[ -z "$LATEST_VERSION" ]]; then
  echo "ERROR: Could not determine latest version from repository" >&2
  exit 1
fi

echo "Latest upstream version: $LATEST_VERSION"

# Extract current version from package.nix
CURRENT_VERSION=$(grep -oP '^\s*version\s*=\s*"\K[^"]+' "$PACKAGE_NIX")

if [[ -z "$CURRENT_VERSION" ]]; then
  echo "ERROR: Could not determine current version from $PACKAGE_NIX" >&2
  exit 1
fi

echo "Current version: $CURRENT_VERSION"

# Compare versions
if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
  echo "Already up to date."
  exit 0
fi

echo "Updating $CURRENT_VERSION -> $LATEST_VERSION ..."

# Prefetch the new .deb and get the SRI hash
DEB_URL="http://repo.yandex.ru/yandex-browser/deb/pool/main/y/yandex-browser-stable/yandex-browser-stable_${LATEST_VERSION}_amd64.deb"
echo "Prefetching $DEB_URL ..."
NAR_HASH=$(nix-prefetch-url "$DEB_URL" 2>/dev/null)
SRI_HASH=$(nix hash convert --hash-algo sha256 --to sri "$NAR_HASH")

echo "New SRI hash: $SRI_HASH"

# Update package.nix
sed -i "s|version = \"${CURRENT_VERSION}\"|version = \"${LATEST_VERSION}\"|" "$PACKAGE_NIX"
sed -i "s|hash = \".*\"|hash = \"${SRI_HASH}\"|" "$PACKAGE_NIX"

echo "Updated package.nix: $CURRENT_VERSION -> $LATEST_VERSION"
