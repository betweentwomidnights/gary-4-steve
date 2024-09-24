//
//  ProcessedAudioPlayerManager.swift
//  gary-for-beatbox
//
//  Created by Kevin Griffing on 9/25/24.
//

import AVFoundation

class ProcessedAudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    @Published var currentPlayingURL: URL?
    private var audioPlayer: AVAudioPlayer?

    func playPauseAudio(url: URL) {
        if self.isPlaying && self.currentPlayingURL == url {
            self.audioPlayer?.stop()
            self.isPlaying = false
            self.currentPlayingURL = nil
        } else {
            do {
                // Set up AVAudioSession
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)

                self.audioPlayer?.stop() // Stop any current playback
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.play()
                self.isPlaying = true
                self.currentPlayingURL = url
            } catch {
                print("Error playing audio: \(error)")
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.isPlaying = false
        self.currentPlayingURL = nil
    }
}
