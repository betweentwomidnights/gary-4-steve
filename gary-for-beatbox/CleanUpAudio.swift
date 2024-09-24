//
//  CleanUpAudio.swift
//  gary-for-beatbox
//
//  Created by Kevin Griffing on 9/24/24.
//

import Foundation

private func cleanupOldProcessedAudioFiles() {
    let fileManager = FileManager.default
    let tempDir = FileManager.default.temporaryDirectory
    
    do {
        let files = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        for file in files {
            if file.lastPathComponent.hasPrefix("processedAudio_") {
                try fileManager.removeItem(at: file)
            }
        }
    } catch {
        print("Error cleaning up old processed audio files: \(error)")
    }
}
