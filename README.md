# TP-7 Utility

A native macOS application for converting between TP-7 multitrack format and individual WAV files.

## Features

- **Smart Auto-Detection**: Automatically detects whether to export or import based on dropped files
- **Export**: Convert TP-7 multitrack recordings (2-12 channels) into individual stereo wav files
- **Import**: Combine up to 6 stereo wav files into a single TP-7 compatible multitrack file
- **Native Swift App**: No external dependencies, uses Core Audio APIs
- **Drag & Drop Interface**: Simple interface with automatic file type detection
- **Finder Integration**: Automatically opens results in Finder after conversion

## Usage

1. Double-click `TP-7 Utility.app` to launch the application
2. Drag and drop files onto the window:
   - **Single multitrack file**: Automatically exports to individual stereo tracks
   - **Multiple stereo files**: Automatically imports to create TP-7 multitrack format
3. Choose the output location when prompted
4. Finder opens automatically to show your converted files

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

## Building from Source

```bash
./build-app.sh
```

Creates `TP-7 Utility.app` with:
- Native Swift executable
- Custom app icon from app_icon.png
- No external dependencies

## Requirements

- macOS 13.0 or later
- No additional software needed

## Distribution

The app is currently unsigned. For first-time use:
1. Right-click the app → "Open" 
2. Click "Open" in the security dialog
3. Future launches work normally with double-click

For professional distribution, code signing and notarization would eliminate security warnings.