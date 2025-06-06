# TP-7 Utility

A native macOS application for converting between TP-7 multitrack format and individual WAV files.

## Features

- **Export**: Convert TP-7 multitrack recordings (2-12 channels) into individual stereo WAV files
- **Import**: Combine up to 6 stereo WAV files into a single TP-7 compatible multitrack file
- **Native Swift App**: No external dependencies, uses Core Audio APIs
- **Drag & Drop Interface**: Intuitive graphical interface with visual feedback

## Usage

### GUI Application

1. Double-click `TP-7 Utility.app` to launch the application
2. Toggle between Export and Import modes
3. Drag and drop files onto the window:
   - **Export mode**: Drop a TP-7 multitrack file (2-12 channel WAV)
   - **Import mode**: Drop up to 6 stereo WAV files
4. Choose the output location when prompted

### Command Line (Legacy Python Tool)

```bash
# Export multitrack to individual files
./tp7-util export recording.WAV

# Import stereo files to multitrack
./tp7-util import track1.wav track2.wav -o multitrack.WAV
```

## Technical Implementation

### TP-7 Format Analysis
- **Storage**: Multitrack recordings as single WAV files with 2-12 channels (1-6 stereo tracks)
- **Original Format**: 24-bit, 48kHz, but app currently exports/imports as 16-bit for compatibility
- **Channel Layout**: Stereo pairs (L1,R1,L2,R2,...) up to 6 tracks maximum

### Development Lessons Learned

1. **Audio Processing Evolution**: 
   - Started with Python/numpy for prototyping
   - Migrated to Swift native implementation using AVFoundation
   - Finally used ExtAudioFile API for better format compatibility

2. **Memory Management**: 
   - Initial approach caused stack buffer overflow with large files
   - Solution: Chunked processing (8192 frames) with heap allocation
   - Critical for handling long recordings (4+ minutes)

3. **Format Compatibility**:
   - 24-bit audio handling proved complex with Swift/Core Audio
   - 16-bit works reliably for proof of concept
   - Can enhance to 24-bit once core functionality is stable

4. **macOS Integration**:
   - Native Swift app provides better user experience
   - Proper app bundle with custom icon
   - File dialogs and drag-drop feel natural to macOS users

## Architecture

```
TP-7 Utility.app/
├── Swift UI Interface (ContentView.swift)
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

## Project Evolution

1. **Phase 1**: Command-line Python tool with numpy
2. **Phase 2**: Swift GUI with Python backend 
3. **Phase 3**: Pure Swift native implementation
4. **Current**: Stable export, working on import reliability

The app demonstrates the evolution from prototyping with Python to a polished native macOS application.