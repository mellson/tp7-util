# Mac App Store Distribution Guide

Complete guide for distributing TP-7 Utility on the Mac App Store.

## Prerequisites

### 1. Apple Developer Program
- ✅ Active Apple Developer Program membership ($99/year)
- ✅ Access to App Store Connect

### 2. Certificates Required
You need **different certificates** for App Store vs direct distribution:

```bash
# Check your certificates
security find-identity -v -p codesigning
```

**Required for App Store:**
- `3rd Party Mac Developer Application: Your Name (TEAM_ID)`
- `3rd Party Mac Developer Installer: Your Name (TEAM_ID)` (for pkg signing)

**How to get them:**
1. **Xcode → Settings → Accounts**
2. **Select your Apple ID → Manage Certificates**
3. **Click "+" and add:**
   - "Mac App Store Application"
   - "Mac App Store Installer" 

### 3. App Store Connect Setup
1. **Go to https://appstoreconnect.apple.com**
2. **My Apps → Add New App**
3. **Fill in basic info:**
   - App Name: "TP-7 Utility"
   - Bundle ID: `com.tp7utility.app` (matches your app)
   - SKU: Unique identifier (e.g., "tp7-utility-2025")
   - Platform: macOS

## Build Process

### 1. Update Environment Configuration

Add App Store certificate to your `.env`:
```bash
# Add this line to your .env file
MAC_APP_STORE_ID="3rd Party Mac Developer Application: Your Name (TEAM_ID)"
```

### 2. Build for App Store

```bash
./build-appstore.sh
```

This creates:
- `TP-7 Utility.app` (signed with App Store certificate)
- `TP-7_Utility_AppStore.pkg` (ready for submission)

### 3. Submit to App Store

```bash
./submit-appstore.sh
```

## App Store Requirements Checklist

### App Sandbox Compliance
- ✅ **App Sandbox enabled** (required for App Store)
- ✅ **File access**: User-selected files only
- ✅ **Audio access**: For processing audio files
- ✅ **No network access**: App works offline

### App Store Guidelines
- ✅ **Functionality**: App provides clear value (audio conversion)
- ✅ **UI/UX**: Native SwiftUI interface
- ✅ **Performance**: Efficient audio processing
- ✅ **Privacy**: No data collection
- ✅ **Safety**: No malicious code

### Technical Requirements
- ✅ **macOS version**: Supports macOS 13.0+
- ✅ **Architecture**: Universal (currently ARM64)
- ✅ **Code signing**: Proper App Store certificates
- ✅ **Entitlements**: Sandbox-compliant

## App Store Connect Configuration

### 1. App Information
- **Name**: TP-7 Utility
- **Subtitle**: Audio Conversion for TP-7 Recordings
- **Category**: Music
- **Content Rights**: You own or have rights to use

### 2. Pricing and Availability
- **Price**: Free (recommended) or set price
- **Availability**: All territories or specific regions

### 3. App Metadata

**Description Example:**
```
TP-7 Utility makes it easy to work with Teenage Engineering TP-7 multitrack recordings.

FEATURES:
• Convert TP-7 multitrack files to individual stereo tracks
• Combine stereo files into TP-7 compatible format
• Smart auto-detection of file types
• Native macOS app with drag & drop interface
• No internet connection required

PERFECT FOR:
• TP-7 users who want to edit individual tracks
• Musicians working with multitrack recordings
• Audio engineers processing TP-7 files

The app automatically detects whether you want to export or import based on the files you drop, making the workflow seamless and intuitive.
```

**Keywords**: 
`TP-7, audio, multitrack, conversion, music, recording, teenage engineering`

### 4. Screenshots Required
You'll need to provide screenshots:
- **13-inch displays**: 1280 x 800 pixels
- **15-inch displays**: 1440 x 900 pixels  
- **27-inch displays**: 2560 x 1440 pixels

## Review Process

### 1. Submission
- Upload happens via `submit-appstore.sh` or Xcode Organizer
- Binary appears in App Store Connect within minutes

### 2. Review Timeline
- **Initial review**: 24-48 hours (automated checks)
- **Human review**: 1-7 days typically
- **Updates**: Usually faster than initial submission

### 3. Common Rejection Reasons
- **Sandbox violations**: Make sure app works within sandbox
- **Missing functionality**: Ensure core features work properly
- **UI issues**: Fix any interface problems
- **Metadata issues**: Accurate descriptions and screenshots

## Post-Approval

### 1. Release Options
- **Manual release**: You control when app goes live
- **Automatic release**: Goes live immediately after approval

### 2. Updates
- Use same build process for updates
- Increment version number in `Info.plist`
- Submit via same workflow

### 3. Analytics
- View downloads and revenue in App Store Connect
- Monitor reviews and ratings

## Troubleshooting

### Build Issues
```bash
# Verify certificates
security find-identity -v -p codesigning

# Check entitlements
codesign -d --entitlements :- "TP-7 Utility.app"

# Verify signature
codesign --verify --deep --strict "TP-7 Utility.app"
```

### Upload Issues
- **Wrong certificate**: Ensure using Mac App Store certificates
- **Network timeout**: Check internet connection
- **Invalid package**: Rebuild with `./build-appstore.sh`
- **Account issues**: Verify Apple ID has access to team

### Alternative Upload Method
If script fails, use Xcode Organizer:
1. **Open Xcode → Window → Organizer**
2. **Drag `TP-7_Utility_AppStore.pkg` into window**
3. **Click "Distribute App"**
4. **Follow prompts to upload**

## Key Differences: Direct vs App Store

| Aspect | Direct Distribution | App Store |
|--------|-------------------|-----------|
| **Certificate** | Developer ID Application | Mac App Store Application |
| **Sandbox** | Optional | Required |
| **Distribution** | DMG/ZIP files | App Store only |
| **Updates** | Manual | App Store handles |
| **Discovery** | Your marketing | App Store search |
| **Revenue** | 100% yours | 70% yours (30% to Apple) |
| **User Trust** | Gatekeeper warnings | Fully trusted |

## Success Tips

1. **Test thoroughly** in sandbox environment
2. **Provide clear app description** and keywords
3. **Include quality screenshots** showing app in use
4. **Respond quickly** to reviewer feedback
5. **Keep app updated** with bug fixes and improvements

---

The Mac App Store provides excellent distribution and user trust, making it worth the additional setup for professional app distribution.