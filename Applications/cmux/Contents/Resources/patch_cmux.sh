#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_WORK="$(mktemp -d "${TMPDIR:-/tmp}/cmux-icon.XXXXXX")"
ICONSET_DIR="$TMP_WORK/CMUX.iconset"
FINAL_ICNS="$TMP_WORK/AppIcon.icns"
PLIST_BUDDY="/usr/libexec/PlistBuddy"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
APP_PATH=""
SOURCE_PNG=""

usage() {
  cat <<'EOF'
Usage:
  patch_cmux.sh [APP_PATH] [ICON_PNG]
  patch_cmux.sh [ICON_PNG]
  patch_cmux.sh --app APP_PATH --icon ICON_PNG

Examples:
  patch_cmux.sh /Applications/cmux.app /path/to/icon.png
  patch_cmux.sh /path/to/icon.png
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Error: required command not found: $cmd"
    exit 1
  fi
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--app)
      if [[ $# -lt 2 ]]; then
        echo "❌ Error: --app requires a path."
        usage
        exit 1
      fi
      APP_PATH="$2"
      shift 2
      ;;
    -i|--icon)
      if [[ $# -lt 2 ]]; then
        echo "❌ Error: --icon requires a .png path."
        usage
        exit 1
      fi
      SOURCE_PNG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [[ ${#POSITIONAL[@]} -eq 1 ]]; then
  if [[ -d "${POSITIONAL[0]}" ]]; then
    APP_PATH="${POSITIONAL[0]}"
  elif [[ -f "${POSITIONAL[0]}" ]]; then
    SOURCE_PNG="${POSITIONAL[0]}"
  else
    APP_PATH="${POSITIONAL[0]}"
  fi
elif [[ ${#POSITIONAL[@]} -ge 2 ]]; then
  [[ -z "$APP_PATH" ]] && APP_PATH="${POSITIONAL[0]}"
  [[ -z "$SOURCE_PNG" ]] && SOURCE_PNG="${POSITIONAL[1]}"
fi

[[ -z "$APP_PATH" ]] && APP_PATH="${CMUX_APP_PATH:-}"
if [[ -z "$APP_PATH" ]]; then
  for candidate in "/Applications/cmux.app" "$HOME/Applications/cmux.app"; do
    if [[ -d "$candidate" ]]; then
      APP_PATH="$candidate"
      break
    fi
  done
fi

cleanup() {
  rm -rf "$TMP_WORK"
}
trap cleanup EXIT

if [[ -z "$APP_PATH" ]]; then
  echo "❌ Error: cmux.app not found in /Applications or ~/Applications."
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ Error: cmux.app path does not exist: $APP_PATH"
  exit 1
fi

require_cmd sips
require_cmd iconutil
if [[ ! -x "$PLIST_BUDDY" ]]; then
  echo "❌ Error: missing $PLIST_BUDDY"
  exit 1
fi

[[ -z "$SOURCE_PNG" ]] && SOURCE_PNG="${CMUX_ICON_SOURCE:-}"
if [[ -z "$SOURCE_PNG" ]]; then
  if [[ -f "$SCRIPT_DIR/icon.png" ]]; then
    SOURCE_PNG="$SCRIPT_DIR/icon.png"
  fi
fi

if [[ -z "$SOURCE_PNG" ]]; then
  candidates=(
    "$HOME/Downloads/icon.png"
    "$HOME/Downloads/icon (1).png"
    "$HOME/Downloads/icon (2).png"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      if [[ -z "$SOURCE_PNG" || "$candidate" -nt "$SOURCE_PNG" ]]; then
        SOURCE_PNG="$candidate"
      fi
    fi
  done
fi

if [[ -z "$SOURCE_PNG" || ! -f "$SOURCE_PNG" ]]; then
  echo "❌ Error: source icon not found. Pass one as:"
  echo "   patch_cmux.sh /path/to/cmux.app /path/to/icon.png"
  exit 1
fi

echo "🚀 Starting CMUX icon patch for $APP_PATH..."
echo "🎯 Icon source: $SOURCE_PNG"

icon_width="$(sips -g pixelWidth "$SOURCE_PNG" 2>/dev/null | awk '/pixelWidth:/ {print $2}')"
icon_height="$(sips -g pixelHeight "$SOURCE_PNG" 2>/dev/null | awk '/pixelHeight:/ {print $2}')"
if [[ -n "$icon_width" && -n "$icon_height" ]]; then
  echo "📐 Icon dimensions: ${icon_width}x${icon_height}"
  if (( icon_width < 1024 || icon_height < 1024 )); then
    echo "⚠️  Warning: icon is smaller than 1024x1024; Dock icon may look soft."
  fi
fi

write_test="$APP_PATH/Contents/Resources/.cmux-write-test.$$"
if ! touch "$write_test" >/dev/null 2>&1; then
  echo "❌ Error: cannot write to $APP_PATH/Contents/Resources"
  echo "   Fix: grant App Management to your terminal app in"
  echo "   System Settings -> Privacy & Security -> App Management"
  echo "   Then run again (prefer without sudo if app bundle is user-owned)."
  exit 1
fi
rm -f "$write_test" >/dev/null 2>&1 || true

# 1. Create iconset resolutions.
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null 2>&1
sips -z 32 32 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null 2>&1
sips -z 32 32 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null 2>&1
sips -z 64 64 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null 2>&1
sips -z 128 128 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null 2>&1
sips -z 256 256 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1
sips -z 256 256 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null 2>&1
sips -z 512 512 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1
sips -z 512 512 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null 2>&1
sips -z 1024 1024 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1

# 2. Convert to ICNS.
icon_updated=0
if iconutil -c icns "$ICONSET_DIR" -o "$FINAL_ICNS"; then
  if cp "$FINAL_ICNS" "$APP_PATH/Contents/Resources/AppIcon.icns"; then
    icon_updated=1
  else
    echo "❌ Error: macOS blocked writing to $APP_PATH/Contents/Resources/AppIcon.icns"
    echo "   This is usually Privacy & Security -> App Management permission."
    echo "   Grant App Management to your terminal app (Terminal/iTerm/Warp/Amp), then rerun."
    echo "   If this app bundle is user-owned, run without sudo:"
    echo "   ./patch_cmux.sh \"$APP_PATH\" \"$SOURCE_PNG\""
    exit 1
  fi
else
  echo "⚠️  iconutil failed. Keeping existing $APP_PATH/Contents/Resources/AppIcon.icns"
fi

# 3. Inject icon and force Info.plist to use .icns over Assets.car.
if [[ "$icon_updated" -eq 0 && ! -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]]; then
  echo "❌ Error: no AppIcon.icns available in app bundle and icon generation failed."
  exit 1
fi

PLIST_PATH="$APP_PATH/Contents/Info.plist"

# CFBundleIconName points to Assets.car and wins over AppIcon.icns.
if "$PLIST_BUDDY" -c "Print :CFBundleIconName" "$PLIST_PATH" >/dev/null 2>&1; then
  "$PLIST_BUDDY" -c "Delete :CFBundleIconName" "$PLIST_PATH" >/dev/null 2>&1 || true
fi
"$PLIST_BUDDY" -c "Set :CFBundleIconFile AppIcon" "$PLIST_PATH" >/dev/null 2>&1 \
  || "$PLIST_BUDDY" -c "Add :CFBundleIconFile string AppIcon" "$PLIST_PATH"

# 4. Refresh LaunchServices and Dock icon cache without sudo/rm.
touch "$APP_PATH/Contents/Resources/AppIcon.icns" "$PLIST_PATH" "$APP_PATH"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP_PATH" >/dev/null 2>&1 || true
fi
killall Dock >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true

echo "✅ Success! Relaunch cmux if it is currently running."
