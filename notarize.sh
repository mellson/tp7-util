#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
    echo "Loaded configuration from .env"
else
    echo "Error: .env file not found. Please create one based on .env.example"
    exit 1
fi

APP_NAME="TP-7 Utility.app"
ZIP_NAME="TP-7_Utility_for_notarization.zip"

# Check if app exists
if [ ! -d "$APP_NAME" ]; then
    echo "Error: $APP_NAME not found. Run ./build-app.sh first."
    exit 1
fi

# Create ZIP for notarization
echo "Creating ZIP for notarization..."
ditto -c -k --keepParent "$APP_NAME" "$ZIP_NAME"

# Submit for notarization
echo "Submitting for notarization..."
if [ -n "$NOTARIZATION_PROFILE" ]; then
    xcrun notarytool submit "$ZIP_NAME" --keychain-profile "$NOTARIZATION_PROFILE" --wait
    
    if [ $? -eq 0 ]; then
        echo "Notarization successful! Stapling ticket to app..."
        xcrun stapler staple "$APP_NAME"
        xcrun stapler validate "$APP_NAME"
        
        # Create final distribution files
        echo "Creating distribution files..."
        hdiutil create -volname "TP-7 Utility" -srcfolder "$APP_NAME" -ov -format UDZO "TP-7_Utility_NOTARIZED.dmg"
        zip -r "TP-7_Utility_NOTARIZED.zip" "$APP_NAME"
        
        echo "✅ Notarization complete!"
        echo "Distribution files created:"
        echo "  - TP-7_Utility_NOTARIZED.dmg"
        echo "  - TP-7_Utility_NOTARIZED.zip"
    else
        echo "❌ Notarization failed"
        exit 1
    fi
else
    echo "Error: NOTARIZATION_PROFILE not set in .env"
    exit 1
fi

# Clean up temporary ZIP
rm "$ZIP_NAME"