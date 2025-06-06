import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct ContentView: View {
    @State private var isDragOver = false
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @State private var droppedFiles: [URL] = []
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("TP-7 Utility")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Drop audio files to convert")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            // Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundColor(isDragOver ? .accentColor : Color.gray.opacity(0.5))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDragOver ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
                    )
                
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(isDragOver ? .accentColor : .gray)
                    
                    Text("Drop TP-7 multitrack file to export\nor stereo wav files to import")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .frame(height: 150)
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
                return true
            }
            
            // Status
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(statusMessage.contains("Error") ? .red : .green)
                    .padding(.horizontal)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 300)
        .overlay(
            Group {
                if isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView("Processing...")
                        .padding()
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(8)
                        .shadow(radius: 10)
                }
            }
        )
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        droppedFiles.removeAll()
        
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        self.droppedFiles.append(url)
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.processFiles()
        }
    }
    
    private func processFiles() {
        guard !droppedFiles.isEmpty else { return }
        
        // Auto-detect operation based on files
        if droppedFiles.count == 1 {
            // Single file - check if it's multitrack for export
            detectAndProcess(singleFile: droppedFiles[0])
        } else {
            // Multiple files - assume import operation
            guard droppedFiles.count <= 6 else {
                statusMessage = "Error: Maximum 6 files allowed for import"
                return
            }
            importToMultitrack(files: droppedFiles)
        }
    }
    
    private func detectAndProcess(singleFile: URL) {
        // Try to read the file to determine channel count
        var inputFile: ExtAudioFileRef?
        let status = ExtAudioFileOpenURL(singleFile as CFURL, &inputFile)
        
        guard status == noErr, let audioFile = inputFile else {
            statusMessage = "Error: Could not read audio file"
            return
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
            statusMessage = "Error: Could not read file format"
            return
        }
        
        let channelCount = fileFormat.mChannelsPerFrame
        
        if channelCount > 2 && channelCount <= 12 && channelCount % 2 == 0 {
            // Multitrack file - export
            exportMultitrack(file: singleFile)
        } else if channelCount == 2 {
            // Stereo file - import (treat as single file import)
            importToMultitrack(files: [singleFile])
        } else {
            statusMessage = "Error: Unsupported audio format (\(channelCount) channels)"
        }
    }
    
    private func exportMultitrack(file: URL) {
        // Show save panel for output directory
        let savePanel = NSOpenPanel()
        savePanel.title = "Choose Output Directory"
        savePanel.message = "Select where to save the exported tracks"
        savePanel.canChooseFiles = false
        savePanel.canChooseDirectories = true
        savePanel.canCreateDirectories = true
        savePanel.allowsMultipleSelection = false
        
        savePanel.begin { response in
            guard response == .OK, let outputDir = savePanel.url else {
                self.statusMessage = "Export cancelled"
                return
            }
            
            self.isProcessing = true
            self.statusMessage = ""
            
            Task {
                do {
                    try AudioProcessor.shared.exportMultitrack(from: file, to: outputDir)
                    await MainActor.run {
                        self.isProcessing = false
                        self.statusMessage = "Successfully exported tracks!"
                        // Open destination folder in Finder
                        NSWorkspace.shared.open(outputDir)
                    }
                } catch {
                    await MainActor.run {
                        self.isProcessing = false
                        self.statusMessage = "Error: \(error.localizedDescription)"
                        print("Export error: \(error)")
                    }
                }
            }
        }
    }
    
    private func importToMultitrack(files: [URL]) {
        // Show save panel for output file
        let savePanel = NSSavePanel()
        savePanel.title = "Save TP-7 Multitrack File"
        savePanel.message = "Choose where to save the multitrack file"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "wav")!]
        savePanel.nameFieldStringValue = "multitrack.wav"
        
        savePanel.begin { response in
            guard response == .OK, let outputFile = savePanel.url else {
                self.statusMessage = "Import cancelled"
                return
            }
            
            self.isProcessing = true
            self.statusMessage = ""
            
            Task {
                do {
                    try AudioProcessor.shared.importToMultitrack(from: files, to: outputFile)
                    await MainActor.run {
                        self.isProcessing = false
                        self.statusMessage = "Successfully created multitrack file!"
                        // Open containing folder and select the file in Finder
                        NSWorkspace.shared.activateFileViewerSelecting([outputFile])
                    }
                } catch {
                    await MainActor.run {
                        self.isProcessing = false
                        self.statusMessage = "Error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}