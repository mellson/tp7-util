# CLAUDE.md - TP-7 Utility Development Guide

## Project Overview

This project evolved from a simple Python prototype to a polished native macOS application for converting between TP-7 multitrack recordings and individual WAV files. This document captures the development journey, technical decisions, and lessons learned.

## Development Phases

### Phase 1: Research & Prototyping (Python)
**Initial Analysis:**
- Analyzed TP-7 example file: 12-channel, 24-bit, 48kHz WAV
- Discovered channel layout: 6 stereo pairs (L1,R1,L2,R2,...,L6,R6)
- Built working Python prototype using numpy for proof of concept

**Key Files:**
- `tp7_util.py` - Command-line tool with export/import functionality
- Successfully handled 24-bit audio with custom byte manipulation

### Phase 2: macOS GUI with Python Backend
**Hybrid Approach:**
- Created SwiftUI interface for better user experience
- Maintained Python backend for audio processing
- Added drag & drop, file dialogs, proper macOS integration

**Issues Encountered:**
- Python dependency made distribution complex
- User needed to install Python + numpy
- Not a true "native" macOS experience

### Phase 3: Pure Swift Implementation
**Migration Challenges:**
1. **Audio Framework Selection:**
   - Started with AVFoundation/AVAudioFile
   - Hit format compatibility issues with TP-7 files
   - Migrated to ExtAudioFile API for better format support

2. **Memory Management Crisis:**
   - Initial approach caused stack buffer overflow
   - Large audio files (252 seconds = 12M+ frames) exhausted stack
   - **Solution:** Chunked processing (8192 frames) with heap allocation

3. **24-bit Audio Complexity:**
   - 24-bit handling in Swift/Core Audio proved problematic
   - **Workaround:** Use 16-bit for now, enhance to 24-bit later
   - 16-bit works reliably for proof of concept

## Technical Architecture

### Current Implementation
```
TP-7 Utility.app/
├── SwiftUI Interface (ContentView.swift)
│   ├── Drag & Drop handling
│   ├── Mode toggle (Export/Import)
│   └── File save dialogs
├── Audio Engine (AudioProcessor.swift)
│   ├── ExtAudioFile API usage
│   ├── Chunked processing (8192 frames)
│   └── Format conversion logic
└── App Bundle
    ├── Custom icon (app_icon.png)
    ├── Info.plist configuration
    └── No external dependencies
```

### Audio Processing Pipeline

**Export (Multitrack → Individual):**
1. Open TP-7 file with ExtAudioFile
2. Validate channel count (2-12, even numbers only)
3. Set client format to float32 for processing
4. Read in 8192-frame chunks to avoid stack overflow
5. Deinterleave stereo pairs from multitrack stream
6. Write individual 16-bit stereo WAV files

**Import (Individual → Multitrack):**
1. Validate input files (max 6, all stereo, same sample rate)
2. Determine output channel count (2 × number of files)
3. Process in chunks, interleaving stereo pairs
4. Write combined multitrack file

## Critical Lessons Learned

### 1. Stack vs Heap Allocation
**Problem:** Initial code allocated large arrays on stack
```swift
// BAD: Stack allocation for large files
let audioBuffer = [Float](repeating: 0, count: totalSamples) // Stack overflow!
```

**Solution:** Heap allocation with proper cleanup
```swift
// GOOD: Heap allocation with defer cleanup
let audioBuffer = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
defer { audioBuffer.deallocate() }
```

### 2. Audio Format Compatibility
**AVAudioFile Issues:**
- Struggled with TP-7's specific 24-bit format
- "Unsupported audio format" errors

**ExtAudioFile Success:**
- Better format compatibility
- More control over client/file format separation
- Industry standard for professional audio applications

### 3. Memory-Efficient Processing
**Chunked Processing Pattern:**
```swift
let chunkSize: UInt32 = 8192  // Sweet spot for memory vs performance
while totalFramesProcessed < frameCount {
    let framesToProcess = min(chunkSize, remaining)
    // Process chunk...
    totalFramesProcessed += Int64(framesToProcess)
}
```

### 4. Cross-Platform Development Strategy
1. **Prototype in Python:** Fast iteration, great libraries (numpy)
2. **Hybrid Phase:** SwiftUI frontend, Python backend
3. **Native Implementation:** Pure Swift for performance and distribution

## Build System

### App Bundle Creation
```bash
./build-app.sh
```
1. Compiles Swift code with release optimizations
2. Creates proper macOS app bundle structure
3. Converts PNG icon to ICNS format (all required sizes)
4. Bundles everything into `TP-7 Utility.app`

### Development Workflow
```bash
# Development iterations
swift build              # Quick compile check
./build-app.sh          # Full app bundle
open "TP-7 Utility.app" # Test
```

## Testing Strategy

### Test Cases Validated
1. **Export Edge Cases:**
   - 2-channel (1 stereo track) files
   - 12-channel (6 stereo tracks) files
   - Long recordings (4+ minutes)
   - Various sample rates (44.1kHz, 48kHz)

2. **Import Scenarios:**
   - Single file import
   - Multiple files (2-6 tracks)
   - Mismatched sample rates (proper error handling)
   - Non-stereo files (proper validation)

3. **Memory Stress Tests:**
   - Large files that previously caused crashes
   - Multiple consecutive operations
   - Rapid mode switching

## Known Limitations & Future Enhancements

### Current Limitations
1. **16-bit Only:** Currently exports/imports 16-bit for compatibility
2. **No Real-time Preview:** Cannot preview tracks before conversion
3. **Fixed Chunk Size:** 8192 frames works well but not optimized per system

### Planned Enhancements
1. **24-bit Support:** Enhance to match TP-7's native format
2. **Progress Indicators:** Show conversion progress for long files
3. **Batch Processing:** Multiple file operations
4. **Audio Preview:** Waveform display and playback

## Distribution Notes

### App Signing & Notarization
- Currently unsigned (local development)
- For distribution, would need Apple Developer account
- Code signing and notarization required for Gatekeeper

### System Requirements
- macOS 13.0+ (for SwiftUI features used)
- No additional dependencies
- ~1MB app size (very lightweight)

## Debug Information

### Common Issues & Solutions

**"Failed to write audio file":**
- Check output directory permissions
- Verify disk space
- Ensure output format compatibility

**"Unsupported audio format":**
- File may not be from TP-7 device
- Corrupted file headers
- Unsupported sample rate/bit depth combo

**App crashes on large files:**
- Verify chunked processing is working
- Check memory allocation patterns
- Monitor heap usage during conversion

### Debugging Commands
```bash
# Run from terminal to see debug output
./TP7Utility/.build/debug/TP7Utility

# Monitor memory usage
leaks TP7Utility

# Check audio file properties
afinfo filename.wav
```

## Code Quality Notes

### Swift Best Practices Followed
- Proper error handling with Result types
- Memory safety with defer statements
- Resource cleanup (ExtAudioFileDispose)
- Async processing for UI responsiveness

### Performance Optimizations
- Chunked processing prevents memory spikes
- Heap allocation for large buffers
- Efficient audio format conversion
- Minimal UI updates during processing

## Conclusion

This project demonstrates the evolution from prototype to production, showcasing how initial Python experimentation can inform a native implementation. The key insight was that audio processing requires careful memory management and format compatibility considerations that aren't immediately obvious.

The final Swift implementation provides a superior user experience while maintaining the core functionality discovered during prototyping. The chunked processing approach and ExtAudioFile usage are the critical technical decisions that made the native implementation viable.

---

**Development Context:** This CLAUDE.md was created to document the complete development journey, technical decisions, and lessons learned during the creation of TP-7 Utility. It serves as both historical record and future development guide.