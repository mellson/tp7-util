#!/bin/bash

# Build the app
cd TP7Utility
swift build -c release

# Create app bundle structure
APP_NAME="TP-7 Utility.app"
APP_DIR="../$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp .build/release/TP7Utility "$APP_DIR/Contents/MacOS/"

# Copy Info.plist
cp Sources/TP7Utility/Info.plist "$APP_DIR/Contents/"

# Convert PNG icon to ICNS format
if [ -f "../app_icon.png" ]; then
    echo "Creating app icon..."
    mkdir -p "$APP_DIR/Contents/Resources/AppIcon.iconset"
    
    # Create different sizes for the iconset
    sips -z 16 16     ../app_icon.png --out "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_16x16.png" >/dev/null 2>&1
    sips -z 32 32     ../app_icon.png --out "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_16x16@2x.png" >/dev/null 2>&1
    sips -z 32 32     ../app_icon.png --out "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_32x32.png" >/dev/null 2>&1
    sips -z 64 64     ../app_icon.png --out "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_32x32@2x.png" >/dev/null 2>&1
    sips -z 128 128   ../app_icon.png --out "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_128x128.png" >/dev/null 2>&1
    sips -z 256 256   ../app_icon.png --out "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   ../app_icon.png --out "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_256x256.png" >/dev/null 2>&1
    sips -z 512 512   ../app_icon.png --out "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   ../app_icon.png --out "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_512x512.png" >/dev/null 2>&1
    sips -z 1024 1024 ../app_icon.png --out "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_512x512@2x.png" >/dev/null 2>&1
    
    # Create the icns file
    iconutil -c icns "$APP_DIR/Contents/Resources/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
    
    # Clean up the iconset
    rm -rf "$APP_DIR/Contents/Resources/AppIcon.iconset"
    
    echo "App icon created successfully!"
else
    echo "Warning: app_icon.png not found, skipping icon creation"
fi

echo "App bundle created at: $APP_DIR"
echo "You can now double-click '$APP_NAME' to run the app!"
echo ""
echo "This is now a standalone macOS app with no Python dependencies!"