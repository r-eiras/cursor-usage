#!/bin/bash
# Install or update Cursor Usage from this project's GitHub releases.
#
# Why this script exists
# ----------------------
# The app is ad hoc signed and not notarized. macOS tags files written by
# browsers and by Homebrew Cask with the com.apple.quarantine attribute, and
# that attribute is what makes Gatekeeper assess the app on first launch. On a
# Mac that only allows identified developers -- the default, and what most
# managed Macs enforce -- the assessment rejects an ad hoc signature: the app
# is terminated and its bundle is moved to the Trash.
#
# curl does not set that attribute, so a copy fetched here is never assessed.
# This script does not disable Gatekeeper, does not change any system setting,
# and never strips an attribute: it refuses to install a quarantined copy
# instead. Notarizing the app with a Developer ID remains the only fix that
# makes every install path work, including Homebrew and browser downloads.
#
# Usage
#   ./install.sh              # install the latest release
#   ./install.sh 3.2.0        # install a specific version

set -euo pipefail

REPO="r-eiras/cursor-usage"
TARGET="/Applications/Cursor Usage.app"
MIN_MACOS_MAJOR=14

fail() { echo "Error: $*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "this installer only runs on macOS."
[ "$(uname -m)" = "arm64" ] || fail "this release is Apple Silicon only; $(uname -m) is not supported."

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$macos_major" -ge "$MIN_MACOS_MAJOR" ] ||
  fail "macOS 14 (Sonoma) or later is required; this Mac reports $(sw_vers -productVersion)."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

version="${1:-}"
if [ -z "$version" ]; then
  echo "Looking up the latest release of $REPO..."
  curl -fsSL -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/releases/latest" -o release.json ||
    fail "could not reach the GitHub API. Check your connection and try again."
  version="$(/usr/bin/python3 -I -c "
import json
print(json.load(open('release.json'))['tag_name'].lstrip('v'))
")"
fi
echo "Version: $version"

archive="CursorUsage-$version-macOS-arm64.zip"
base="https://github.com/$REPO/releases/download/v$version"

echo "Downloading $archive..."
curl -fsSL -o "$archive" "$base/$archive" ||
  fail "could not download $archive. Check that version $version has a macOS arm64 asset."
curl -fsSL -o manifest.json "$base/manifest.json" ||
  fail "could not download manifest.json for version $version."

expected="$(/usr/bin/python3 -I -c "
import json, sys
archives = json.load(open('manifest.json')).get('archives', {})
name = sys.argv[1]
if name not in archives:
    sys.exit('the manifest does not list ' + name)
print(archives[name])
" "$archive")"
actual="$(shasum -a 256 "$archive" | cut -d' ' -f1)"
[ "$expected" = "$actual" ] ||
  fail "checksum mismatch for $archive. Expected $expected, got $actual. The download was not installed."
echo "Checksum verified against the release manifest."

if xattr "$archive" 2>/dev/null | grep -q com.apple.quarantine; then
  fail "the download carries com.apple.quarantine, so Gatekeeper would block it. Nothing was installed."
fi

ditto -xk "$archive" extracted
app="extracted/Cursor Usage.app"
[ -d "$app" ] || fail "the archive did not contain Cursor Usage.app."
codesign --verify --strict "$app" || fail "the downloaded app failed signature verification."

was_running=0
if pgrep -f "$TARGET/Contents/MacOS/CursorUsage" >/dev/null 2>&1; then
  was_running=1
  echo "Quitting the running app..."
  pkill -TERM -f "$TARGET/Contents/MacOS/CursorUsage" || true
  sleep 2
fi

echo "Installing to $TARGET..."
rm -rf "$TARGET"
ditto "$app" "$TARGET"

if xattr "$TARGET" 2>/dev/null | grep -q com.apple.quarantine; then
  fail "the installed bundle is quarantined and would be blocked on launch."
fi
codesign --verify --strict "$TARGET" || fail "the installed app failed signature verification."

echo "Installed Cursor Usage $version."
echo "Your preferences and account session in ~/Library/Application Support/CursorUsage are kept."
if [ "$was_running" -eq 1 ]; then
  open "$TARGET"
  echo "Relaunched. The indicator is in the menu bar, near the clock."
else
  echo "Open it with: open \"$TARGET\""
fi
