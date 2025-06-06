#!/bin/bash

# Mac App Store Submission Script for TP-7 Utility

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
    echo "Loaded configuration from .env"
else
    echo "Error: .env file not found!"
    exit 1
fi

PKG_NAME="TP-7_Utility_AppStore.pkg"

# Check if package exists
if [ ! -f "$PKG_NAME" ]; then
    echo "Error: $PKG_NAME not found!"
    echo "Please run './build-appstore.sh' first to create the App Store package."
    exit 1
fi

echo "Submitting TP-7 Utility to Mac App Store..."
echo "Package: $PKG_NAME"

# Method 1: Using xcrun altool (traditional method)
echo "Uploading using xcrun altool..."

if [ -n "$NOTARIZATION_PROFILE" ]; then
    # Use stored keychain profile (recommended)
    xcrun altool --upload-app --type osx --file "$PKG_NAME" \
        --keychain-profile "$NOTARIZATION_PROFILE" \
        --verbose
else
    # Fallback to username/password (requires app-specific password)
    echo "Note: Using username/password method"
    echo "You'll need to enter your app-specific password when prompted"
    
    if [ -z "$APPLE_ID" ]; then
        echo "Error: APPLE_ID not set in .env file!"
        exit 1
    fi
    
    xcrun altool --upload-app --type osx --file "$PKG_NAME" \
        --username "$APPLE_ID" \
        --password "@keychain:AC_PASSWORD" \
        --verbose
fi

if [ $? -eq 0 ]; then
    echo "✅ Successfully uploaded to App Store Connect!"
    echo ""
    echo "Next steps:"
    echo "1. Go to https://appstoreconnect.apple.com"
    echo "2. Navigate to your app"
    echo "3. Add metadata (description, screenshots, etc.)"
    echo "4. Submit for review"
    echo ""
    echo "The app will appear in App Store Connect within a few minutes."
else
    echo "❌ Upload failed!"
    echo ""
    echo "Common solutions:"
    echo "1. Check your internet connection"
    echo "2. Verify your Apple ID credentials"
    echo "3. Ensure your app has been created in App Store Connect"
    echo "4. Try using Xcode Organizer as an alternative:"
    echo "   - Open Xcode → Window → Organizer"
    echo "   - Drag $PKG_NAME into Organizer"
    echo "   - Click 'Distribute App'"
fi