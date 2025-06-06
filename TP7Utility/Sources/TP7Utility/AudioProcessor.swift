import Foundation
import AVFoundation

class AudioProcessor {
    static let shared = AudioProcessor()
    
    private init() {}
    
    enum ProcessingError: LocalizedError {
        case invalidFile
        case unsupportedFormat
        case channelMismatch(expected: Int, found: Int)
        case tooManyFiles
        case readError
        case writeError
        
        var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "Invalid file format"
            case .unsupportedFormat:
                return "Unsupported audio format"
            case .channelMismatch(_, let found):
                return "Expected even number of channels for stereo pairs, but found \(found)"
            case .tooManyFiles:
                return "Maximum 6 files allowed"
            case .readError:
                return "Failed to read audio file"
            case .writeError:
                return "Failed to write audio file"
            }
        }
    }
    
    // MARK: - Export Multitrack
    
    func exportMultitrack(from inputURL: URL, to outputDirectory: URL) throws {
        // Use ExtAudioFile for better format support
        var inputFile: ExtAudioFileRef?
        let status = ExtAudioFileOpenURL(inputURL as CFURL, &inputFile)
        
        guard status == noErr, let audioFile = inputFile else {
            throw ProcessingError.invalidFile
        }
        
        defer { ExtAudioFileDispose(audioFile) }
        
        // Get file format
        var fileFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        
        let formatStatus = ExtAudioFileGetProperty(
            audioFile,
            kExtAudioFileProperty_FileDataFormat,
            &propertySize,
            &fileFormat
        )
        
        guard formatStatus == noErr else {
            throw ProcessingError.unsupportedFormat
        }
        
        let channelCount = fileFormat.mChannelsPerFrame
        guard channelCount >= 2 && channelCount <= 12 && channelCount % 2 == 0 else {
            throw ProcessingError.channelMismatch(expected: 2, found: Int(channelCount))
        }
        
        // Get file length
        var frameCount: Int64 = 0
        propertySize = UInt32(MemoryLayout<Int64>.size)
        ExtAudioFileGetProperty(
            audioFile,
            kExtAudioFileProperty_FileLengthFrames,
            &propertySize,
            &frameCount
        )
        
        print("Input: \(channelCount) channels, \(fileFormat.mSampleRate) Hz, \(frameCount) frames")
        print("Format: \(fileFormat.mBitsPerChannel)-bit")
        
        // Set up client format (float32 for processing, interleaved)
        var clientFormat = AudioStreamBasicDescription()
        clientFormat.mSampleRate = fileFormat.mSampleRate
        clientFormat.mFormatID = kAudioFormatLinearPCM
        clientFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        clientFormat.mBitsPerChannel = 32
        clientFormat.mChannelsPerFrame = channelCount
        clientFormat.mFramesPerPacket = 1
        clientFormat.mBytesPerFrame = channelCount * 4
        clientFormat.mBytesPerPacket = channelCount * 4
        
        let clientFormatStatus = ExtAudioFileSetProperty(
            audioFile,
            kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
            &clientFormat
        )
        
        guard clientFormatStatus == noErr else {
            throw ProcessingError.unsupportedFormat
        }
        
        // Process in chunks to avoid stack overflow
        let chunkSize: UInt32 = 8192
        let numTracks = Int(channelCount) / 2
        
        // Ensure output directory exists
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Create output files
        var outputFiles: [ExtAudioFileRef] = []
        
        for trackIndex in 0..<numTracks {
            let outputURL = outputDirectory.appendingPathComponent(String(format: "track_%02d.wav", trackIndex + 1))
            
            // Set up output format - use 16-bit for compatibility, we can enhance later
            var outputFormat = AudioStreamBasicDescription()
            outputFormat.mSampleRate = fileFormat.mSampleRate
            outputFormat.mFormatID = kAudioFormatLinearPCM
            outputFormat.mChannelsPerFrame = 2
            outputFormat.mFramesPerPacket = 1
            outputFormat.mBitsPerChannel = 16
            outputFormat.mBytesPerFrame = 4  // 2 channels × 2 bytes per sample
            outputFormat.mBytesPerPacket = 4
            outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
            
            // Create output file
            var outputFile: ExtAudioFileRef?
            let createStatus = ExtAudioFileCreateWithURL(
                outputURL as CFURL,
                kAudioFileWAVEType,
                &outputFormat,
                nil,
                AudioFileFlags.eraseFile.rawValue,
                &outputFile
            )
            
            guard createStatus == noErr, let outFile = outputFile else {
                // Clean up already created files
                for file in outputFiles {
                    ExtAudioFileDispose(file)
                }
                print("Failed to create output file: \(outputURL.path)")
                print("Error code: \(createStatus)")
                throw ProcessingError.writeError
            }
            
            // Set client format (float32, stereo)
            var stereoClientFormat = AudioStreamBasicDescription()
            stereoClientFormat.mSampleRate = fileFormat.mSampleRate
            stereoClientFormat.mFormatID = kAudioFormatLinearPCM
            stereoClientFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
            stereoClientFormat.mBitsPerChannel = 32
            stereoClientFormat.mChannelsPerFrame = 2
            stereoClientFormat.mFramesPerPacket = 1
            stereoClientFormat.mBytesPerFrame = 8
            stereoClientFormat.mBytesPerPacket = 8
            
            ExtAudioFileSetProperty(
                outFile,
                kExtAudioFileProperty_ClientDataFormat,
                UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                &stereoClientFormat
            )
            
            outputFiles.append(outFile)
        }
        
        defer {
            for file in outputFiles {
                ExtAudioFileDispose(file)
            }
        }
        
        // Allocate buffers for processing
        let interleavedBufferSize = Int(chunkSize * channelCount)
        let interleavedBuffer = UnsafeMutablePointer<Float>.allocate(capacity: interleavedBufferSize)
        defer { interleavedBuffer.deallocate() }
        
        let stereoBufferSize = Int(chunkSize * 2)
        let stereoBuffer = UnsafeMutablePointer<Float>.allocate(capacity: stereoBufferSize)
        defer { stereoBuffer.deallocate() }
        
        var totalFramesProcessed: Int64 = 0
        
        while totalFramesProcessed < frameCount {
            let framesToProcess = min(chunkSize, UInt32(frameCount - totalFramesProcessed))
            
            // Read interleaved audio data
            var bufferList = AudioBufferList()
            bufferList.mNumberBuffers = 1
            
            withUnsafeMutablePointer(to: &bufferList.mBuffers) { ptr in
                ptr.withMemoryRebound(to: AudioBuffer.self, capacity: 1) { bufferPtr in
                    bufferPtr[0].mNumberChannels = channelCount
                    bufferPtr[0].mDataByteSize = framesToProcess * channelCount * 4
                    bufferPtr[0].mData = UnsafeMutableRawPointer(interleavedBuffer)
                }
            }
            
            var framesToRead = framesToProcess
            let readStatus = ExtAudioFileRead(audioFile, &framesToRead, &bufferList)
            
            guard readStatus == noErr else {
                throw ProcessingError.readError
            }
            
            // Process each stereo track
            for trackIndex in 0..<numTracks {
                let leftChannelIndex = trackIndex * 2
                let rightChannelIndex = trackIndex * 2 + 1
                
                // Deinterleave stereo data
                for frameIndex in 0..<Int(framesToRead) {
                    let interleavedIndex = frameIndex * Int(channelCount)
                    let stereoIndex = frameIndex * 2
                    
                    stereoBuffer[stereoIndex] = interleavedBuffer[interleavedIndex + leftChannelIndex]
                    stereoBuffer[stereoIndex + 1] = interleavedBuffer[interleavedIndex + rightChannelIndex]
                }
                
                // Write stereo data
                var stereoBufferList = AudioBufferList()
                stereoBufferList.mNumberBuffers = 1
                
                withUnsafeMutablePointer(to: &stereoBufferList.mBuffers) { ptr in
                    ptr.withMemoryRebound(to: AudioBuffer.self, capacity: 1) { bufferPtr in
                        bufferPtr[0].mNumberChannels = 2
                        bufferPtr[0].mDataByteSize = framesToRead * 8
                        bufferPtr[0].mData = UnsafeMutableRawPointer(stereoBuffer)
                    }
                }
                
                let writeStatus = ExtAudioFileWrite(outputFiles[trackIndex], framesToRead, &stereoBufferList)
                guard writeStatus == noErr else {
                    print("Failed to write to track \(trackIndex + 1), error code: \(writeStatus)")
                    throw ProcessingError.writeError
                }
            }
            
            totalFramesProcessed += Int64(framesToRead)
        }
        
        print("Successfully exported \(numTracks) tracks")
    }
    
    // MARK: - Import to Multitrack
    
    func importToMultitrack(from inputURLs: [URL], to outputURL: URL) throws {
        guard inputURLs.count <= 6 else {
            throw ProcessingError.tooManyFiles
        }
        
        var audioFiles: [ExtAudioFileRef] = []
        var maxFrameCount: Int64 = 0
        var referenceSampleRate: Float64?
        
        // Open all input files
        for url in inputURLs {
            var inputFile: ExtAudioFileRef?
            let status = ExtAudioFileOpenURL(url as CFURL, &inputFile)
            
            guard status == noErr, let file = inputFile else {
                // Clean up already opened files
                for openFile in audioFiles {
                    ExtAudioFileDispose(openFile)
                }
                throw ProcessingError.invalidFile
            }
            
            // Get format
            var format = AudioStreamBasicDescription()
            var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &propertySize, &format)
            
            // Verify stereo
            guard format.mChannelsPerFrame == 2 else {
                ExtAudioFileDispose(file)
                for openFile in audioFiles {
                    ExtAudioFileDispose(openFile)
                }
                throw ProcessingError.channelMismatch(expected: 2, found: Int(format.mChannelsPerFrame))
            }
            
            // Check sample rate
            if let refRate = referenceSampleRate {
                guard format.mSampleRate == refRate else {
                    ExtAudioFileDispose(file)
                    for openFile in audioFiles {
                        ExtAudioFileDispose(openFile)
                    }
                    throw ProcessingError.unsupportedFormat
                }
            } else {
                referenceSampleRate = format.mSampleRate
            }
            
            // Get frame count
            var frameCount: Int64 = 0
            propertySize = UInt32(MemoryLayout<Int64>.size)
            ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &propertySize, &frameCount)
            maxFrameCount = max(maxFrameCount, frameCount)
            
            audioFiles.append(file)
        }
        
        defer {
            for file in audioFiles {
                ExtAudioFileDispose(file)
            }
        }
        
        guard let sampleRate = referenceSampleRate else {
            throw ProcessingError.invalidFile
        }
        
        // Create output format - MUST be 12 channels and 24-bit for TP-7 compatibility
        let outputChannels: UInt32 = 12  // Always 12 channels like Python version
        var outputFormat = AudioStreamBasicDescription()
        outputFormat.mSampleRate = sampleRate
        outputFormat.mFormatID = kAudioFormatLinearPCM
        outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        outputFormat.mBitsPerChannel = 24  // Must be 24-bit like original TP-7 files
        outputFormat.mChannelsPerFrame = outputChannels
        outputFormat.mFramesPerPacket = 1
        outputFormat.mBytesPerFrame = outputChannels * 3  // 3 bytes per 24-bit sample
        outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame
        
        // Create output file
        var outputFile: ExtAudioFileRef?
        let createStatus = ExtAudioFileCreateWithURL(
            outputURL as CFURL,
            kAudioFileWAVEType,
            &outputFormat,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &outputFile
        )
        
        guard createStatus == noErr, let outFile = outputFile else {
            print("Failed to create multitrack output file: \(outputURL.path)")
            print("Error code: \(createStatus)")
            throw ProcessingError.writeError
        }
        
        defer { ExtAudioFileDispose(outFile) }
        
        // Set client format (float32)
        var clientFormat = AudioStreamBasicDescription()
        clientFormat.mSampleRate = sampleRate
        clientFormat.mFormatID = kAudioFormatLinearPCM
        clientFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        clientFormat.mBitsPerChannel = 32
        clientFormat.mChannelsPerFrame = outputChannels
        clientFormat.mFramesPerPacket = 1
        clientFormat.mBytesPerFrame = outputChannels * 4
        clientFormat.mBytesPerPacket = clientFormat.mBytesPerFrame
        
        ExtAudioFileSetProperty(
            outFile,
            kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
            &clientFormat
        )
        
        // Set client format for all input files
        for file in audioFiles {
            var stereoClientFormat = AudioStreamBasicDescription()
            stereoClientFormat.mSampleRate = sampleRate
            stereoClientFormat.mFormatID = kAudioFormatLinearPCM
            stereoClientFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
            stereoClientFormat.mBitsPerChannel = 32
            stereoClientFormat.mChannelsPerFrame = 2
            stereoClientFormat.mFramesPerPacket = 1
            stereoClientFormat.mBytesPerFrame = 8
            stereoClientFormat.mBytesPerPacket = 8
            
            ExtAudioFileSetProperty(
                file,
                kExtAudioFileProperty_ClientDataFormat,
                UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                &stereoClientFormat
            )
        }
        
        // Process in chunks
        let chunkSize: UInt32 = 8192
        let multitrackBufferSize = Int(chunkSize * outputChannels)
        let multitrackBuffer = UnsafeMutablePointer<Float>.allocate(capacity: multitrackBufferSize)
        defer { multitrackBuffer.deallocate() }
        
        let stereoBufferSize = Int(chunkSize * 2)
        let stereoBuffer = UnsafeMutablePointer<Float>.allocate(capacity: stereoBufferSize)
        defer { stereoBuffer.deallocate() }
        
        var totalFramesWritten: Int64 = 0
        
        while totalFramesWritten < maxFrameCount {
            let framesToProcess = min(chunkSize, UInt32(maxFrameCount - totalFramesWritten))
            
            // Clear multitrack buffer
            memset(multitrackBuffer, 0, multitrackBufferSize * MemoryLayout<Float>.size)
            
            // Read from each input file
            for (fileIndex, file) in audioFiles.enumerated() {
                var bufferList = AudioBufferList()
                bufferList.mNumberBuffers = 1
                
                withUnsafeMutablePointer(to: &bufferList.mBuffers) { ptr in
                    ptr.withMemoryRebound(to: AudioBuffer.self, capacity: 1) { bufferPtr in
                        bufferPtr[0].mNumberChannels = 2
                        bufferPtr[0].mDataByteSize = framesToProcess * 8
                        bufferPtr[0].mData = UnsafeMutableRawPointer(stereoBuffer)
                    }
                }
                
                var framesToRead = framesToProcess
                ExtAudioFileRead(file, &framesToRead, &bufferList)
                
                // Interleave into multitrack buffer
                let leftChannel = fileIndex * 2
                let rightChannel = fileIndex * 2 + 1
                
                for i in 0..<Int(framesToRead) {
                    multitrackBuffer[i * Int(outputChannels) + leftChannel] = stereoBuffer[i * 2]
                    multitrackBuffer[i * Int(outputChannels) + rightChannel] = stereoBuffer[i * 2 + 1]
                }
            }
            
            // Write to output
            var outputBufferList = AudioBufferList()
            outputBufferList.mNumberBuffers = 1
            
            withUnsafeMutablePointer(to: &outputBufferList.mBuffers) { ptr in
                ptr.withMemoryRebound(to: AudioBuffer.self, capacity: 1) { bufferPtr in
                    bufferPtr[0].mNumberChannels = outputChannels
                    bufferPtr[0].mDataByteSize = framesToProcess * outputChannels * 4
                    bufferPtr[0].mData = UnsafeMutableRawPointer(multitrackBuffer)
                }
            }
            
            let writeStatus = ExtAudioFileWrite(outFile, framesToProcess, &outputBufferList)
            guard writeStatus == noErr else {
                throw ProcessingError.writeError
            }
            
            totalFramesWritten += Int64(framesToProcess)
        }
        
        print("Created 12-channel TP-7 multitrack file with \(audioFiles.count) active stereo track(s)")
    }
}