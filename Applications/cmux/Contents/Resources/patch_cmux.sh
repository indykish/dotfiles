#!/bin/bash

# Configuration
SOURCE_PNG="/Users/kishore/Projects/dotfiles/Applications/cmux.app/Contents/Resources/icon.png"
APP_PATH="/Applications/cmux.app"
ICONSET_DIR="CMUX.iconset"
FINAL_ICNS="AppIcon.icns"

echo "🚀 Starting CMUX icon patch..."

# 1. Create the iconset resolutions
mkdir -p $ICONSET_DIR
sips -z 16 16 $SOURCE_PNG --out $ICONSET_DIR/icon_16x16.png >/dev/null 2>&1
sips -z 32 32 $SOURCE_PNG --out $ICONSET_DIR/icon_16x16@2x.png >/dev/null 2>&1
sips -z 32 32 $SOURCE_PNG --out $ICONSET_DIR/icon_32x32.png >/dev/null 2>&1
sips -z 64 64 $SOURCE_PNG --out $ICONSET_DIR/icon_32x32@2x.png >/dev/null 2>&1
sips -z 128 128 $SOURCE_PNG --out $ICONSET_DIR/icon_128x128.png >/dev/null 2>&1
sips -z 256 256 $SOURCE_PNG --out $ICONSET_DIR/icon_128x128@2x.png >/dev/null 2>&1
sips -z 256 256 $SOURCE_PNG --out $ICONSET_DIR/icon_256x256.png >/dev/null 2>&1
sips -z 512 512 $SOURCE_PNG --out $ICONSET_DIR/icon_256x256@2x.png >/dev/null 2>&1
sips -z 512 512 $SOURCE_PNG --out $ICONSET_DIR/icon_512x512.png >/dev/null 2>&1
sips -z 1024 1024 $SOURCE_PNG --out $ICONSET_DIR/icon_512x512@2x.png >/dev/null 2>&1

# 2. Convert to ICNS
iconutil -c icns $ICONSET_DIR -o $FINAL_ICNS

# 3. Inject into the App
if [ -d "$APP_PATH" ]; then
	echo "Syncing to $APP_PATH..."
	cp $FINAL_ICNS "$APP_PATH/Contents/Resources/AppIcon.icns"

	# Force macOS to notice the change
	touch "$APP_PATH"
	sudo find /private/var/folders/ -name com.apple.dock.iconcache -exec rm {} + 2>/dev/null
	killall Dock
	echo "✅ Success! Your neon CMUX icon is live."
else
	echo "❌ Error: CMUX.app not found in /Applications."
fi

# Cleanup
rm -rf $ICONSET_DIR $FINAL_ICNS
