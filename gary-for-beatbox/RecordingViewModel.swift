import Foundation
import AVFoundation

class RecordingViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false

    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)

            // Set sample rate to 32000 Hz
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 32000, // Updated sample rate
                AVNumberOfChannelsKey: 1,  // Mono recording
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self // Set delegate
            audioRecorder?.record()

            isRecording = true
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        // Do not set isRecording to false here
        // We'll set it in the delegate method
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false

        if flag {
            print("Recording finished successfully.")
        } else {
            print("Recording failed to finish successfully.")
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false)
        } catch {
            print("Failed to deactivate session: \(error.localizedDescription)")
        }

        // Notify that recording is finished and audio file is ready
        DispatchQueue.main.async {
            let audioURL = recorder.url
            NotificationCenter.default.post(name: .recordingFinished, object: nil, userInfo: ["audioURL": audioURL])
        }
    }

    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
