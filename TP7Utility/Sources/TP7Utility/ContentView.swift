import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isExportMode = true
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
                
                Text(isExportMode ? "Export Multitrack to Individual Files" : "Import Files to Multitrack")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            // Mode Toggle
            Picker("Mode", selection: $isExportMode) {
                Text("Export").tag(true)
                Text("Import").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
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
                    Image(systemName: isExportMode ? "doc.badge.arrow.up" : "doc.badge.arrow.down")
                        .font(.system(size: 48))
                        .foregroundColor(isDragOver ? .accentColor : .gray)
                    
                    Text(dropZoneText)
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
    
    private var dropZoneText: String {
        if isExportMode {
            return "Drop TP-7 multitrack file here\n(2-12 channel WAV)"
        } else {
            return "Drop stereo WAV files here\n(max 6 files)"
        }
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
        
        if isExportMode {
            // Export mode - expect single file
            guard droppedFiles.count == 1 else {
                statusMessage = "Error: Export mode requires exactly one file"
                return
            }
            exportMultitrack(file: droppedFiles[0])
        } else {
            // Import mode - can have multiple files
            guard droppedFiles.count <= 6 else {
                statusMessage = "Error: Maximum 6 files allowed for import"
                return
            }
            importToMultitrack(files: droppedFiles)
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