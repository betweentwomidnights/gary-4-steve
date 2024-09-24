import SwiftUI
import AVFoundation

struct ProcessedAudioListView: View {
    @Binding var isPresented: Bool // Binding to control the presentation
    @State private var processedAudioFiles: [URL] = []
    @ObservedObject private var audioPlayerManager = ProcessedAudioPlayerManager()
    @State private var showShareSheet: Bool = false
    @State private var fileToShare: URL? // For tracking the file to share

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(processedAudioFiles, id: \.self) { fileURL in
                        HStack {
                            // Display the filename
                            Text(fileURL.lastPathComponent)
                                .lineLimit(1)
                            Spacer()

                            // Play/Pause Button
                            Button(action: {
                                self.audioPlayerManager.playPauseAudio(url: fileURL)
                            }) {
                                Image(systemName: self.audioPlayerManager.isPlaying && self.audioPlayerManager.currentPlayingURL == fileURL ? "stop.fill" : "play.fill")
                                    .foregroundColor(.blue)
                            }

                            // Share Button
                            Button(action: {
                                self.fileToShare = fileURL
                                self.showShareSheet = true
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                            }

                            // Delete Button
                            Button(action: {
                                self.deleteFile(fileURL: fileURL)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .onAppear {
                    self.loadProcessedAudioFiles()
                }
                .navigationBarTitle("Processed Audio Files", displayMode: .inline)
                .navigationBarItems(leading:
                    Button("Close") {
                        isPresented = false
                    }
                )
                .sheet(isPresented: $showShareSheet) {
                    if let fileToShare = fileToShare {
                        ShareSheet(activityItems: [fileToShare])
                    }
                }

                // Clear History Button
                Button(action: {
                    self.clearHistory()
                }) {
                    Text("Clear History")
                        .foregroundColor(.red)
                }
                .padding()
            }
        }
    }

    private func loadProcessedAudioFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            self.processedAudioFiles = files.filter { $0.lastPathComponent.hasPrefix("processedAudio_") && $0.pathExtension == "wav" }
                .sorted(by: { (url1, url2) -> Bool in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                })
        } catch {
            print("Error loading processed audio files: \(error)")
        }
    }

    private func deleteFile(fileURL: URL) {
        do {
            // Remove file from file system
            try FileManager.default.removeItem(at: fileURL)
            // Update the list
            self.processedAudioFiles.removeAll { $0 == fileURL }
        } catch {
            print("Error deleting file: \(error)")
        }
    }

    private func clearHistory() {
        Utility.cleanupOldProcessedAudioFiles()
        self.processedAudioFiles.removeAll()
    }
}
