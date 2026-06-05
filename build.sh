#!/bin/bash
# ================================================================
# Build BilingualSubtitlesOffline.app
# Now fully offline: uses Apple Translation framework instead of Python
# ================================================================

set -e

APP_NAME="BilingualSubtitlesOffline"
DIR="$(cd "$(dirname "$0")" && pwd)"
DEPS_DIR="$DIR/deps"
APP_BUNDLE="$DIR/build/$APP_NAME.app"
MODULE_CACHE="/tmp/swift-module-cache"
SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

GREEN='\033[0;32m'
NC='\033[0m'
RED='\033[0;31m'

echo "=== Compiling $APP_NAME ==="
mkdir -p "$MODULE_CACHE" "$DIR/build/swift"

# Collect Swift sources
SOURCES=()
while IFS= read -r line; do
    SOURCES+=("$line")
done < <(find "$DIR/Sources/App" -name "*.swift" | sort)

xcrun swiftc \
  -module-cache-path "$MODULE_CACHE" \
  -sdk "$SDK" \
  -target "arm64-apple-macosx26.0" \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework UniformTypeIdentifiers \
  -framework Translation \
  -o "$DIR/build/swift/$APP_NAME" \
  "${SOURCES[@]}" \
  -O \
  -whole-module-optimization

echo -e "${GREEN}✅ Swift compilation successful${NC}"

echo ""
echo "=== Creating Self-Contained .app Bundle ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 1. Swift binary
cp "$DIR/build/swift/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 2. whisper.cpp CLI binary
WHISPER_CLI="$DEPS_DIR/whisper.cpp/build/bin/whisper-cli"
if [ -f "$WHISPER_CLI" ]; then
    cp "$WHISPER_CLI" "$APP_BUNDLE/Contents/Resources/whisper-cli"
    echo "   ✅ Bundled: whisper-cli ($(du -h "$APP_BUNDLE/Contents/Resources/whisper-cli" | cut -f1))"
else
    echo -e "   ${RED}⚠️  whisper-cli not found. Run ./setup.sh first.${NC}"
fi

# 3. Model files
MODEL_SRC="/Users/terry/Library/CloudStorage/SynologyDrive-Home/Codex/TTS/BilingualSubtitlesOffline/deps/models"
if [ -d "$MODEL_SRC" ]; then
    count=0
    for f in "$MODEL_SRC"/*.bin; do
        if [ -f "$f" ]; then
            cp "$f" "$APP_BUNDLE/Contents/Resources/"
            echo "   ✅ Bundled: $(basename $f) ($(du -h "$f" | cut -f1))"
            ((count++))
        fi
    done
    if [ $count -eq 0 ]; then
        echo -e "   ${RED}⚠️  No model files found. Run ./setup.sh first.${NC}"
    fi
fi

# 4. App icon
if [ -f "/tmp/app_icon/icon_1024.png" ]; then
    cp "/tmp/app_icon/icon_1024.png" "$APP_BUNDLE/Contents/Resources/icon.png"
    echo "   ✅ Bundled: app icon"
fi

# 5. Bundle ffmpeg (from Homebrew or system PATH)
FFMPEG_PATH=$(which ffmpeg 2>/dev/null)
if [ -n "$FFMPEG_PATH" ]; then
    FFMPEG_REAL=$(realpath "$FFMPEG_PATH")
    mkdir -p "$APP_BUNDLE/Contents/Resources/bin"
    cp "$FFMPEG_REAL" "$APP_BUNDLE/Contents/Resources/bin/ffmpeg"
    chmod +x "$APP_BUNDLE/Contents/Resources/bin/ffmpeg"
    
    # Bundle dylib dependencies (skip system libraries)
    COPIED=""
    bundle_dylib() {
        local lib="$1"
        [ -z "$lib" ] && return
        echo "$lib" | grep -qE '^/(System|usr/lib)' && return
        echo "$COPIED" | grep -qF "$lib" && return
        COPIED="$COPIED $lib"
        local base=$(basename "$lib")
        cp -n "$lib" "$APP_BUNDLE/Contents/Resources/bin/$base" 2>/dev/null || true
        while IFS= read -r dep; do
            dep=$(echo "$dep" | awk '{print $1}')
            bundle_dylib "$dep"
        done < <(otool -L "$lib" 2>/dev/null | tail -n +2 | grep -vE '^/(System|usr/lib)')
    }
    while IFS= read -r dep; do
        dep=$(echo "$dep" | awk '{print $1}')
        bundle_dylib "$dep"
    done < <(otool -L "$FFMPEG_REAL" 2>/dev/null | tail -n +2 | grep -vE '^/(System|usr/lib)')
    
    # Fix install names
    for lib in "$APP_BUNDLE/Contents/Resources/bin"/*.dylib; do
        [ -f "$lib" ] || continue
        base=$(basename "$lib")
        install_name_tool -id "@loader_path/$base" "$lib" 2>/dev/null || true
        while IFS= read -r dep; do
            dep_path=$(echo "$dep" | awk '{print $1}')
            dep_base=$(basename "$dep_path")
            echo "$dep_path" | grep -qE '^/(System|usr/lib)' && continue
            install_name_tool -change "$dep_path" "@loader_path/$dep_base" "$lib" 2>/dev/null || true
        done < <(otool -L "$lib" 2>/dev/null | tail -n +2)
    done
    while IFS= read -r dep; do
        dep_path=$(echo "$dep" | awk '{print $1}')
        dep_base=$(basename "$dep_path")
        echo "$dep_path" | grep -qE '^/(System|usr/lib)' && continue
        install_name_tool -change "$dep_path" "@loader_path/$dep_base" "$APP_BUNDLE/Contents/Resources/bin/ffmpeg" 2>/dev/null || true
    done < <(otool -L "$APP_BUNDLE/Contents/Resources/bin/ffmpeg" 2>/dev/null | tail -n +2)
    
    echo "   ✅ Bundled: ffmpeg ($(du -h "$APP_BUNDLE/Contents/Resources/bin/ffmpeg" | cut -f1), $(ls -1 "$APP_BUNDLE/Contents/Resources/bin"/*.dylib 2>/dev/null | wc -l) dylibs)"
else
    echo "   ⚠️  ffmpeg not found — AVFoundation 回退（MKV/WebM/AVI 等格式不可用）"
fi

# 6. Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.codex.bilingualsubtitles.offline</string>
    <key>CFBundleName</key>
    <string>离线双语字幕生成器</string>
    <key>CFBundleDisplayName</key>
    <string>离线双语字幕生成器</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>4</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>icon</string>
</dict>
</plist>
PLIST
echo ""
echo "=== Code-Signing .app Bundle ==="
for lib in "$APP_BUNDLE/Contents/Resources/bin"/*.dylib; do
    [ -f "$lib" ] || continue
    codesign -f -s - "$lib" 2>/dev/null || true
done
codesign -f -s - "$APP_BUNDLE/Contents/Resources/bin/ffmpeg" 2>/dev/null || true
codesign --deep -f -s - "$APP_BUNDLE" 2>/dev/null || true
echo "   ✅ Code-signed (ad-hoc)"


echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✅ App Bundle Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Location:"
echo "  $APP_BUNDLE"
echo ""
echo "Size:"
du -sh "$APP_BUNDLE"
echo ""
echo "Contents:"
echo "  📦 app binary ($(du -h "$APP_BUNDLE/Contents/MacOS/$APP_NAME" | cut -f1))"
for dir in "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Resources/bin"; do
    if [ -d "$dir" ]; then
        find "$dir" -maxdepth 1 -type f -exec basename {} \; | while read f; do
            size=$(du -h "$dir/$f" | cut -f1)
            echo "  📦 $f ($size)"
        done
    fi
done
echo ""
echo "Run: open \"$APP_BUNDLE\""
