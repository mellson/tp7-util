# TP-7 Utility

A native macOS application for converting between Teenage Engineerings [TP-7](https://teenage.engineering/products/tp-7) multitrack format and individual WAV files.

## Features

- **Smart Auto-Detection**: Automatically detects whether to export or import based on dropped files
- **Export**: Convert TP-7 multitrack recordings (2-12 channels) into individual stereo wav files
- **Import**: Combine up to 6 stereo wav files into a single TP-7 compatible multitrack file
- **Native Swift App**: No external dependencies, uses Core Audio APIs
- **Drag & Drop Interface**: Simple interface with automatic file type detection
- **Finder Integration**: Automatically opens results in Finder after conversion

## Getting Started

### Prerequisites

- macOS 13.0 or later
- Xcode (for Swift compiler)
- **For code signing**: Active Apple Developer Program membership

### Setting Up Code Signing (Required)

To build and sign the app, you need an Apple Developer account:

1. **Get Apple Developer Program Membership**
   - Visit https://developer.apple.com/programs/
   - Enroll in the Apple Developer Program ($99/year)

2. **Download Developer ID Application Certificate**
   - Open **Xcode → Settings → Accounts**
   - Add your Apple ID and select your team
   - Click **"Manage Certificates..."**
   - Click **"+"** and select **"Developer ID Application"**
   - This downloads the certificate needed for app distribution

3. **Create Configuration File**
   ```bash
   cp .env.example .env
   ```
   
4. **Edit .env with Your Details**
   ```bash
   # Find your certificate name
   security find-identity -v -p codesigning
   
   # Find your team ID at https://developer.apple.com/account
   ```
   
   Update `.env` with your information:
   ```
   DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
   TEAM_ID="YOUR_TEAM_ID"
   APPLE_ID="your.email@example.com"
   NOTARIZATION_PROFILE="your-notarization-profile"
   ```

### Building the App

```bash
./build-app.sh
```

This creates a properly signed `TP-7 Utility.app` with no external dependencies.

### Optional: Notarization (Recommended)

For the best user experience (no security warnings):

1. **Create App-Specific Password**
   - Go to https://appleid.apple.com/account/manage
   - Generate app-specific password for "TP7 Notarization"

2. **Store Notarization Credentials**
   ```bash
   xcrun notarytool store-credentials "TP7-notarization" \
       --apple-id "your.email@example.com" \
       --team-id "YOUR_TEAM_ID" \
       --password "your-app-specific-password"
   ```

3. **Build and Notarize**
   ```bash
   ./build-app.sh    # Build and sign
   ./notarize.sh     # Submit for notarization
   ```

This creates distribution-ready `TP-7_Utility_NOTARIZED.dmg` and `.zip` files.

### Using the App

1. **Launch the App**
   - **Notarized version**: Double-click to launch immediately
   - **Signed but not notarized**: Right-click → "Open" → "Open" (first time only)

2. **Convert Files**
   - Drag and drop files onto the window:
     - **Single multitrack file**: Automatically exports to individual stereo tracks
     - **Multiple stereo files**: Automatically imports to create TP-7 multitrack format
   - Choose the output location when prompted
   - Finder opens automatically to show your converted files

## Technical Implementation

### TP-7 Format Specifications
- **Storage**: Multitrack recordings as single WAV files with 2-12 channels (1-6 stereo tracks)
- **Format**: 24-bit, 48kHz (import creates TP-7 compatible 24-bit files)
- **Channel Layout**: Interleaved stereo pairs (L1,R1,L2,R2,...) up to 6 tracks maximum
- **Compatibility**: Import always creates 12-channel files for full TP-7 compatibility

### Key Technical Features

1. **Memory Efficient Processing**: 
   - Chunked processing (8192 frames) prevents memory overflow
   - Heap allocation for large audio buffers
   - Handles long recordings (4+ minutes) reliably

2. **Format Compatibility**:
   - Uses ExtAudioFile API for robust format support
   - Export: Creates 16-bit wav files for broad compatibility
   - Import: Creates 24-bit, 12-channel files exactly as TP-7 expects

3. **Smart File Detection**:
   - Automatically analyzes audio files to determine operation
   - No manual mode switching required
   - Supports various input formats

## Architecture

```
TP-7 Utility.app/
├── SwiftUI Interface (ContentView.swift)
├── Audio Processing Engine (AudioProcessor.swift)
└── Core Audio APIs (ExtAudioFile)
```

## Requirements

- macOS 13.0 or later
- Swift (for building from source)
- No additional runtime dependencies

## Distribution

### Code Signing Requirements

This project requires proper code signing for distribution:

- **Developer ID Application certificate** is required to build
- **Notarization** is recommended for the best user experience
- The build process will fail without proper Apple Developer credentials

### For Contributors

To contribute to this project, you need:
1. Apple Developer Program membership
2. Developer ID Application certificate
3. Configured `.env` file (see setup instructions above)

Without these, the build script will exit with an error to prevent unsigned builds.
