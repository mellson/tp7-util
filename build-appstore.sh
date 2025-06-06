#!/bin/bash

# Mac App Store Build Script for TP-7 Utility

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
    echo "Loaded configuration from .env"
else
    echo "Error: .env file not found!"
    echo "Please create a .env file based on .env.example with your Apple Developer credentials."
    echo "See README.md for setup instructions."
    exit 1
fi

# Validate App Store certificate
if [ -z "$MAC_APP_STORE_ID" ]; then
    echo "Error: MAC_APP_STORE_ID not set in .env file!"
    echo "Please add your Mac App Store Application certificate name to .env"
    echo "Example: MAC_APP_STORE_ID=\"3rd Party Mac Developer Application: Your Name (TEAM_ID)\""
    exit 1
fi

echo "Building TP-7 Utility for Mac App Store submission..."
echo "Certificate: $MAC_APP_STORE_ID"

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

# Copy Info.plist (App Store version needs specific settings)
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

# Sign the app bundle with Mac App Store certificate
echo "Signing app for Mac App Store..."
codesign --force --deep --sign "$MAC_APP_STORE_ID" --options=runtime --entitlements ../entitlements-appstore.plist "$APP_DIR"

# Verify signature
if codesign --verify --deep --strict "$APP_DIR"; then
    echo "App successfully signed for Mac App Store!"
    
    # Verify sandbox entitlements
    echo "Checking sandbox entitlements..."
    codesign -d --entitlements :- "$APP_DIR" | grep -q "com.apple.security.app-sandbox"
    if [ $? -eq 0 ]; then
        echo "✅ App Sandbox entitlement verified"
    else
        echo "❌ Warning: App Sandbox entitlement not found"
    fi
else
    echo "Error: Code signing failed!"
    echo "Please check:"
    echo "  1. Your Mac App Store Application certificate is installed"
    echo "  2. The certificate name in .env matches exactly"
    echo "  3. You have an active Apple Developer Program membership"
    exit 1
fi

# Create pkg for App Store submission
PKG_NAME="TP-7_Utility_AppStore.pkg"
echo "Creating installer package: $PKG_NAME"

if [ -n "$MAC_INSTALLER_ID" ]; then
    echo "Using installer certificate: $MAC_INSTALLER_ID"
    productbuild --component "$APP_DIR" /Applications --sign "$MAC_INSTALLER_ID" "../$PKG_NAME"
else
    echo "Warning: MAC_INSTALLER_ID not set, creating unsigned package"
    productbuild --component "$APP_DIR" /Applications "../$PKG_NAME"
fi

if [ $? -eq 0 ]; then
    echo "✅ App Store package created successfully!"
    echo "Package: $PKG_NAME"
    echo ""
    echo "Next steps:"
    echo "1. Use './submit-appstore.sh' to upload to App Store Connect"
    echo "2. Or manually upload using Xcode → Window → Organizer → Distribute App"
else
    echo "❌ Error creating App Store package"
    exit 1
fi

echo ""
echo "App Store build complete!"
echo "Files created:"
echo "  - $APP_NAME (signed for App Store)"
echo "  - $PKG_NAME (ready for submission)"