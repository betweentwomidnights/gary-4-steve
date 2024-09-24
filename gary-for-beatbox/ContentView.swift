import SwiftUI
import AVFoundation
import FDWaveformView

struct ContentView: View {
    @StateObject private var recordingVM = RecordingViewModel()
    @StateObject private var webSocketManager = WebSocketManager()
    @StateObject private var recordingPlayerManager = AudioPlayerManager(id: "recorded")
    @StateObject private var processedPlayerManager = AudioPlayerManager(id: "processed")
    @State private var recordedTotalSamples: Int = 0
    @State private var processedTotalSamples: Int = 0
    @State private var processedAudioURL: URL?
    @State private var isProcessing: Bool = false
    @State private var showShareSheet = false // To show share sheet

    @State private var showSettings = false
    @AppStorage("modelName") private var modelName = "thepatch/vanya_ai_dnb_0.1"
    @AppStorage("promptDuration") private var promptDuration = 6

    @State private var showProcessedAudioList = false

    @State private var recordedAudioURL: URL? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection Indicator and Settings Button
                HStack {
                    Text("status:")
                    Circle()
                        .fill(webSocketManager.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    Text(webSocketManager.isConnected ? "connected" : "disconnected")
                    Spacer()
                    HStack(spacing: 20) {
                        // Menu icon
                        Button(action: {
                            self.showProcessedAudioList = true
                        }) {
                            Image(systemName: "line.horizontal.3")
                                .font(.title)
                                .padding()
                        }
                        // Settings icon
                        Button(action: {
                            self.showSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.title)
                                .padding()
                        }
                    }
                }
                .font(.subheadline)
                .padding(.top, 10)

                // Display progress bar if processing
                if webSocketManager.progress > 0 && webSocketManager.progress < 100 {
                    ProgressView("Processing: \(webSocketManager.progress)%", value: Double(webSocketManager.progress), total: 100)
                        .padding()
                }

                if recordingVM.isRecording {
                    Text("recording rn")
                        .font(.headline)
                        .padding(.bottom, 10)
                } else {
                    Text("done recording bro")
                        .font(.headline)
                        .padding(.bottom, 10)

                    // Recorded Audio Waveform
                    WaveformViewWrapper(
                        id: "recorded",
                        audioURL: $recordedAudioURL,
                        totalSamples: $recordedTotalSamples,
                        onTap: nil,
                        onSeek: { time in
                            self.recordingPlayerManager.seek(to: time)
                        }
                    )
                    .frame(height: 150)

                    // Play/Pause and Stop Buttons for Recording
                    HStack(spacing: 20) {
                        Button(action: playRecording) {
                            Image(systemName: recordingPlayerManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black)
                                .cornerRadius(8)
                        }

                        if recordingPlayerManager.isPlaying {
                            Button(action: stopRecording) {
                                Image(systemName: "stop.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black)
                                    .cornerRadius(8)
                            }
                        }

                        Button(action: sendRecording) {
                            Text("send to gary")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding()
                                .background(isProcessing || webSocketManager.progress > 0 ? Color.gray : Color.black)
                                .cornerRadius(8)
                        }
                        .disabled(isProcessing || webSocketManager.progress > 0)
                    }
                }

                // Record/Stop Button
                Button(action: toggleRecording) {
                    Image(systemName: recordingVM.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding()
                        .background(recordingVM.isRecording ? Color.red : Color.black)
                        .cornerRadius(8)
                }

                // Processed Audio Section
                if let processedAudioURL = processedAudioURL {
                    WaveformViewWrapper(
                        id: "processed",
                        audioURL: $processedAudioURL,
                        totalSamples: $processedTotalSamples,
                        onTap: nil,
                        onSeek: { time in
                            self.processedPlayerManager.seek(to: time)
                        }
                    )
                    .frame(height: 150)

                    // Play/Pause, Stop, Crop, and Share Buttons
                    HStack(spacing: 20) {
                        Button(action: playProcessedAudio) {
                            Image(systemName: processedPlayerManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black)
                                .cornerRadius(8)
                        }

                        if processedPlayerManager.isPlaying {
                            Button(action: stopProcessedAudio) {
                                Image(systemName: "stop.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black)
                                    .cornerRadius(8)
                            }
                        }

                        Button(action: cropAudio) {
                            Image(systemName: "crop")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(isProcessing || webSocketManager.progress > 0 ? Color.gray : Color.black)
                                .cornerRadius(8)
                        }
                        .disabled(isProcessing || webSocketManager.progress > 0)

                        // Share Button
                        Button(action: {
                            showShareSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .sheet(isPresented: $showShareSheet) {
                            // No need to force unwrap processedAudioURL here as it's already non-optional
                            ShareSheet(activityItems: [processedAudioURL])
                        }
                    }

                    // Continue and Retry Buttons
                    HStack(spacing: 20) {
                        Button(action: continueMusic) {
                            Text("continue")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding()
                                .background(isProcessing || webSocketManager.progress > 0 || webSocketManager.sessionID == nil ? Color.gray : Color.black)
                                .cornerRadius(8)
                        }
                        .disabled(isProcessing || webSocketManager.progress > 0 || webSocketManager.sessionID == nil)

                        Button(action: retryMusic) {
                            Text("retry")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding()
                                .background(isProcessing || webSocketManager.progress > 0 || webSocketManager.sessionID == nil ? Color.gray : Color.black)
                                .cornerRadius(8)
                        }
                        .disabled(isProcessing || webSocketManager.progress > 0 || webSocketManager.sessionID == nil)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            // Initialize recordedAudioURL if there's an existing recording
            self.recordedAudioURL = getAudioURL()

            // Connect to WebSocket when the view appears
            webSocketManager.setupSocketConnection()

            // Listen for the processed audio notification
            NotificationCenter.default.addObserver(forName: .processedAudioReady, object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo, let url = userInfo["processedAudioURL"] as? URL {
                    print("Received processed audio URL: \(url)")
                    self.processedAudioURL = url
                    self.processedPlayerManager.setAudioURL(url)

                    // Set progress to 100% and then reset it to 0 after processing
                    self.webSocketManager.progress = 100

                    // Delay to simulate finalizing and then reset progress and processing state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.webSocketManager.progress = 0
                        self.isProcessing = false  // Ensure buttons are re-enabled
                    }
                }
            }

            // Listen for recording finished notification
            NotificationCenter.default.addObserver(forName: .recordingFinished, object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo, let url = userInfo["audioURL"] as? URL {
                    print("Recording finished, audio URL: \(url)")
                    self.recordedAudioURL = url
                    self.recordingPlayerManager.setAudioURL(url)
                }
            }
        }
        .onDisappear {
            // Close WebSocket when the view disappears
            webSocketManager.closeSocketConnection()
            NotificationCenter.default.removeObserver(self)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(modelName: $modelName, promptDuration: $promptDuration, isPresented: $showSettings)
        }
        .sheet(isPresented: $showProcessedAudioList) {
            ProcessedAudioListView(isPresented: $showProcessedAudioList)
        }
    }

    // MARK: - Helper Methods

    // Remove getAudioURL() if not needed
    private func getAudioURL() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("recording.m4a")
    }

    private func toggleRecording() {
        if recordingVM.isRecording {
            recordingVM.stopRecording()
        } else {
            recordingVM.startRecording()
        }
    }

    private func playRecording() {
        guard let url = recordedAudioURL else { return }
        if recordingPlayerManager.isPlaying {
            recordingPlayerManager.pausePlayback()
        } else {
            recordingPlayerManager.startPlayback(with: url)
        }
    }

    private func stopRecording() {
        recordingPlayerManager.stopPlayback()
    }

    private func playProcessedAudio() {
        guard let url = processedAudioURL else { return }
        if processedPlayerManager.isPlaying {
            processedPlayerManager.pausePlayback()
        } else {
            processedPlayerManager.startPlayback(with: url)
        }
    }

    private func stopProcessedAudio() {
        processedPlayerManager.stopPlayback()
    }

    // MARK: - Audio Processing Methods
    
    private func continueMusic() {
        guard !isProcessing else {
            print("Processing already in progress.")
            return
        }

        isProcessing = true
        webSocketManager.continueMusic(modelName: modelName, promptDuration: promptDuration)
    }

    private func retryMusic() {
        guard !isProcessing else {
            print("Processing already in progress.")
            return
        }

        isProcessing = true
        webSocketManager.retryMusic(modelName: modelName, promptDuration: promptDuration)
    }

    private func sendRecording() {
        guard !isProcessing else {
            print("Processing already in progress.")
            return
        }

        guard let url = recordedAudioURL else {
            print("No recorded audio to send.")
            return
        }

        do {
            isProcessing = true

            if let wavUrl = try convertM4aToWav(url) {
                let audioData = try Data(contentsOf: wavUrl)
                let paddedAudioData = padAudioTo30Seconds(audioData: audioData, sampleRate: 32000)
                let base64String = paddedAudioData.base64EncodedString()
                webSocketManager.sendAudioData(audioBase64: base64String, modelName: modelName, promptDuration: promptDuration)
            } else {
                print("Error: WAV conversion failed")
            }
        } catch {
            print("Error during recording or conversion: \(error)")
        }
    }

    private func convertM4aToWav(_ inputUrl: URL) throws -> URL? {
        let outputUrl = FileManager.default.temporaryDirectory.appendingPathComponent("convertedRecording.wav")
        let audioFile = try AVAudioFile(forReading: inputUrl)
        let format = audioFile.processingFormat
        let outputFile = try AVAudioFile(forWriting: outputUrl, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 32000,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ])

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioFile.length))!
        try audioFile.read(into: buffer)
        try outputFile.write(from: buffer)

        return outputUrl
    }

    private func padAudioTo30Seconds(audioData: Data, sampleRate: Int) -> Data {
        let bytesPerSample = 2
        let channels = 1
        let totalDuration: TimeInterval = 30.0
        let audioDuration = Double(audioData.count) / Double(sampleRate * bytesPerSample * channels)

        if audioDuration >= totalDuration {
            return audioData
        }

        let paddingDuration = totalDuration - audioDuration
        let paddingSamples = Int(paddingDuration * Double(sampleRate))
        let silence = Data(repeating: 0, count: paddingSamples * bytesPerSample * channels)

        var paddedAudioData = audioData
        paddedAudioData.append(silence)

        return paddedAudioData
    }

    private func cropAudio() {
        guard let processedAudioURL = processedAudioURL else {
            print("No processed audio to crop.")
            return
        }

        let currentTime = processedPlayerManager.currentTime

        guard currentTime > 0 else {
            print("Current playback time is zero. Cannot crop.")
            return
        }

        isProcessing = true

        do {
            let audioFile = try AVAudioFile(forReading: processedAudioURL)
            let sampleRate = audioFile.fileFormat.sampleRate
            let totalFrames = audioFile.length

            let endFrame = AVAudioFramePosition(currentTime * sampleRate)
            let framesToRead = min(endFrame, totalFrames)

            guard framesToRead > 0 else {
                isProcessing = false
                return
            }

            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("processedAudio_cropped_\(UUID().uuidString).wav")
            let outputFile = try AVAudioFile(forWriting: outputURL, settings: audioFile.fileFormat.settings)

            audioFile.framePosition = 0
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(framesToRead))!
            try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(framesToRead))
            try outputFile.write(from: buffer)

            DispatchQueue.main.async {
                self.processedAudioURL = outputURL
                do {
                    let audioData = try Data(contentsOf: outputURL)
                    let audioBase64 = audioData.base64EncodedString()
                    self.webSocketManager.updateCroppedAudio(audioBase64: audioBase64)
                } catch {
                    print("Error reading cropped audio data: \(error)")
                }
                self.isProcessing = false
            }
        } catch {
            isProcessing = false
        }
    }
}






// MARK: - WaveformViewWrapper

struct WaveformViewWrapper: UIViewRepresentable {
    var id: String // Unique identifier
    @Binding var audioURL: URL?
    @Binding var totalSamples: Int
    var onTap: (() -> Void)?
    var onSeek: ((TimeInterval) -> Void)? // New closure for seeking

    func makeUIView(context: Context) -> FDWaveformView {
        let waveformView = FDWaveformView()
        waveformView.delegate = context.coordinator
        context.coordinator.waveformView = waveformView

        if let url = audioURL {
            waveformView.audioURL = url
            customizeWaveformAppearance(waveformView)
            context.coordinator.lastAudioURL = url
        }

        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        waveformView.addGestureRecognizer(tapGesture)

        return waveformView
    }

    func updateUIView(_ uiView: FDWaveformView, context: Context) {
        if let url = audioURL, url != context.coordinator.lastAudioURL {
            uiView.audioURL = url
            context.coordinator.lastAudioURL = url
            customizeWaveformAppearance(uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, id: id)
    }

    private func customizeWaveformAppearance(_ waveformView: FDWaveformView) {
        waveformView.wavesColor = UIColor.red
        waveformView.progressColor = UIColor(red: 128/255, green: 0, blue: 0, alpha: 1)

        // Enable user interactions if needed
        waveformView.doesAllowScrubbing = false
        waveformView.doesAllowScroll = false
    }

    class Coordinator: NSObject, FDWaveformViewDelegate {
        var parent: WaveformViewWrapper
        var waveformView: FDWaveformView?
        var lastAudioURL: URL?
        var id: String
        var audioDuration: TimeInterval? // New property

        init(_ parent: WaveformViewWrapper, id: String) {
            self.parent = parent
            self.id = id
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(updateProgress(notification:)), name: .waveformProgressUpdate, object: nil)
        }

        @objc func updateProgress(notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let notificationId = userInfo["id"] as? String,
                  notificationId == self.id,
                  let currentTime = userInfo["currentTime"] as? TimeInterval,
                  let duration = userInfo["duration"] as? TimeInterval else { return }

            guard let waveformView = waveformView else { return }

            let progressSamples = Int((currentTime / duration) * Double(waveformView.totalSamples))
            waveformView.highlightedSamples = 0..<progressSamples
        }

        @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let waveformView = waveformView else { return }
            let location = gestureRecognizer.location(in: waveformView)
            let xPosition = location.x

            let waveformWidth = waveformView.bounds.width
            let progress = xPosition / waveformWidth

            guard let duration = self.audioDuration else { return }
            let newTime = duration * Double(progress)

            // Update the highlighted samples
            let totalSamples = waveformView.totalSamples
            let newSamplePosition = Int(Double(totalSamples) * progress)
            waveformView.highlightedSamples = 0..<newSamplePosition

            // Call the onSeek closure with the new time
            DispatchQueue.main.async {
                self.parent.onSeek?(newTime)
            }
        }

        func waveformViewDidLoad(_ waveformView: FDWaveformView) {
            self.waveformView = waveformView
            parent.totalSamples = waveformView.totalSamples

            if let audioURL = waveformView.audioURL {
                let asset = AVURLAsset(url: audioURL)
                let duration = CMTimeGetSeconds(asset.duration)
                self.audioDuration = duration
            } else {
                self.audioDuration = nil
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}




// MARK: - Notification Names Extension

extension Notification.Name {
    static let waveformProgressUpdate = Notification.Name("waveformProgressUpdate")
    static let processedAudioReady = Notification.Name("processedAudioReady")
    static let recordingFinished = Notification.Name("recordingFinished") // Add this line
}
