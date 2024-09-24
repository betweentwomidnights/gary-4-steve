import AVFoundation
import SwiftUI

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    private var audioPlayer: AVAudioPlayer?
    private var audioURL: URL?
    private var audioFileModificationDate: Date?
    var id: String

    init(id: String) {
        self.id = id
        super.init()
    }

    func setAudioURL(_ url: URL) {
        self.audioURL = url

        var fileHasChanged = false
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let modificationDate = attributes[FileAttributeKey.modificationDate] as? Date

            if let previousDate = audioFileModificationDate {
                if modificationDate != previousDate {
                    fileHasChanged = true
                }
            } else {
                fileHasChanged = true
            }

            audioFileModificationDate = modificationDate
        } catch {
            print("Error getting file attributes: \(error.localizedDescription)")
            fileHasChanged = true
        }

        if fileHasChanged {
            print("Audio file has changed, resetting audioPlayer")
            audioPlayer = nil
        }
    }

    func startPlayback(with url: URL) {
        do {
            // Set up AVAudioSession
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            self.audioURL = url // Store the audio URL

            if audioPlayer == nil {
                // Initialize new audio player
                print("Attempting to initialize AVAudioPlayer with URL: \(url)")

                if FileManager.default.fileExists(atPath: url.path) {
                    print("File exists at path: \(url.path)")
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = fileAttributes[FileAttributeKey.size] as? NSNumber
                    print("File size: \(fileSize?.intValue ?? 0) bytes")
                } else {
                    print("File does not exist at path: \(url.path)")
                }

                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
                audioPlayer?.prepareToPlay()
            }

            let success = audioPlayer?.play() ?? false
            if success {
                isPlaying = true
                startProgressUpdates()
                print("Audio playback started/resumed successfully.")
            } else {
                print("Failed to start/resume audio playback.")
            }
        } catch {
            print("Error starting playback: \(error.localizedDescription)")
        }
    }

    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressUpdates()
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        stopProgressUpdates()
        sendProgressUpdate() // Update waveform after stopping
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopProgressUpdates()
    }

    // Progress updates
    private var progressTimer: Timer?

    private func startProgressUpdates() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.sendProgressUpdate()
        }
    }

    private func stopProgressUpdates() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func sendProgressUpdate() {
        guard let player = audioPlayer else { return }
        let currentTime = player.currentTime
        let duration = player.duration
        NotificationCenter.default.post(name: .waveformProgressUpdate, object: nil, userInfo: ["id": self.id, "currentTime": currentTime, "duration": duration])
    }

    func seek(to time: TimeInterval) {
        if audioPlayer == nil {
            // Initialize audioPlayer if it's nil
            guard let url = self.audioURL else {
                print("AudioPlayer is nil and audioURL is nil, cannot seek.")
                return
            }
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
                audioPlayer?.prepareToPlay()
                print("AudioPlayer initialized for seeking.")
            } catch {
                print("Error initializing audioPlayer for seeking: \(error.localizedDescription)")
                return
            }
        }
        audioPlayer?.currentTime = time
        sendProgressUpdate()
    }

    var currentTime: TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }
}
