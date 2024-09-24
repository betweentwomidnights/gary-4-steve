import Foundation
import SocketIO

class WebSocketManager: ObservableObject {
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    @Published var isConnected: Bool = false
    @Published var progress: Int = 0 // New property to track generation progress
    var sessionID: String? // New property to store session ID

    init() {
        setupSocketConnection()
    }

    func setupSocketConnection() {
        if socket?.status == .connected {
            print("Socket is already connected")
            return
        }

        guard let url = URL(string: "https://g4l.thecollabagepatch.com") else {
            print("Invalid WebSocket URL")
            isConnected = false
            return
        }

        manager = SocketManager(socketURL: url, config: [.log(true), .compress, .forceWebsockets(true)])
        socket = manager?.defaultSocket

        socket?.on(clientEvent: .connect) { data, ack in
            print("Socket.IO connected")
            self.isConnected = true
        }

        socket?.on(clientEvent: .disconnect) { data, ack in
            print("Socket.IO disconnected")
            self.isConnected = false
        }

        socket?.on(clientEvent: .error) { data, ack in
            print("Socket.IO error: \(data)")
            self.isConnected = false
        }

        socket?.on("audio_processed") { [weak self] data, ack in
            guard let strongSelf = self else { return }
            print("Received processed audio data from server.")

            if let response = data[0] as? [String: Any],
               let base64Audio = response["audio_data"] as? String {
                print("Received base64 audio data: \(base64Audio.prefix(100))...")

                // Save the base64 string as a .wav file
                if let audioURL = strongSelf.saveBase64ToWav(base64String: base64Audio) {
                    print("Processed audio saved at: \(audioURL)")
                    
                    // Notify ContentView that processed audio is ready
                    NotificationCenter.default.post(name: .processedAudioReady, object: nil, userInfo: ["processedAudioURL": audioURL])
                    
                    // Store the session ID
                    if let sessionID = response["session_id"] as? String {
                        strongSelf.sessionID = sessionID
                        print("Session ID updated: \(sessionID)")
                    }
                }
            }
        }
        socket?.on("music_continued") { [weak self] data, ack in
            guard let strongSelf = self else { return }
            print("Received continued music data from server.")

            if let response = data[0] as? [String: Any],
               let base64Audio = response["audio_data"] as? String {
                print("Received base64 audio data: \(base64Audio.prefix(100))...")

                // Save the base64 string as a .wav file
                if let audioURL = strongSelf.saveBase64ToWav(base64String: base64Audio) {
                    print("Continued audio saved at: \(audioURL)")
                    
                    // Notify ContentView that processed audio is ready
                    NotificationCenter.default.post(name: .processedAudioReady, object: nil, userInfo: ["processedAudioURL": audioURL])
                    
                    // Update the session ID
                    if let sessionID = response["session_id"] as? String {
                        strongSelf.sessionID = sessionID
                        print("Session ID updated: \(sessionID)")
                    }
                }
            }
        }
        
        socket?.on("music_retried") { [weak self] data, ack in
            guard let strongSelf = self else { return }
            print("Received retried music data from server.")

            if let response = data[0] as? [String: Any],
               let base64Audio = response["audio_data"] as? String {
                print("Received base64 audio data: \(base64Audio.prefix(100))...")

                // Save the base64 string as a .wav file
                if let audioURL = strongSelf.saveBase64ToWav(base64String: base64Audio) {
                    print("Retried audio saved at: \(audioURL)")

                    // Notify ContentView that processed audio is ready
                    NotificationCenter.default.post(name: .processedAudioReady, object: nil, userInfo: ["processedAudioURL": audioURL])

                    // Update the session ID
                    if let sessionID = response["session_id"] as? String {
                        strongSelf.sessionID = sessionID
                        print("Session ID updated: \(sessionID)")
                    }
                }
            }
        }
        
        socket?.on("update_cropped_audio_complete") { [weak self] data, ack in
            print("Received update_cropped_audio_complete from server.")
            // Handle any UI updates if necessary
        }
        
        socket?.on("progress_update") { [weak self] data, ack in
                    guard let strongSelf = self else { return }
                    if let response = data[0] as? [String: Any],
                       let progressValue = response["progress"] as? Int {
                        print("Progress update received: \(progressValue)%")
                        DispatchQueue.main.async {
                            strongSelf.progress = progressValue
                        }
                    }
                }


        socket?.connect()
    }

    func sendAudioData(audioBase64: String, modelName: String, promptDuration: Int) {
        guard socket?.status == .connected else {
            print("Socket is not connected")
            return
        }

        // Manually construct the raw JSON string
        let jsonString = """
        {"audio_data":"\(audioBase64)", "model_name":"\(modelName)", "prompt_duration":\(promptDuration)}
        """

        print("Sending raw JSON string: \(jsonString)")

        // Send the raw JSON string to Socket.IO
        socket?.emit("process_audio_request", jsonString)
    }

    private func saveBase64ToWav(base64String: String) -> URL? {
        guard let audioData = Data(base64Encoded: base64String) else {
            print("Error decoding base64 audio data.")
            return nil
        }

        // Generate a unique file name using UUID
        let uniqueFileName = "processedAudio_\(UUID().uuidString).wav"
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueFileName)
        
        do {
            try audioData.write(to: audioURL)
            return audioURL
        } catch {
            print("Error writing processed audio to file: \(error)")
            return nil
        }
    }
    
    func continueMusic(modelName: String, promptDuration: Int) {
        guard socket?.status == .connected else {
            print("Socket is not connected")
            return
        }

        guard let sessionID = sessionID else {
            print("No session ID available")
            return
        }

        // Get the last processed audio URL
        guard let processedAudioURL = getLastProcessedAudioURL() else {
            print("No processed audio available for continuation")
            return
        }

        do {
            // Read and base64-encode the last processed audio data
            let audioData = try Data(contentsOf: processedAudioURL)
            let audioBase64 = audioData.base64EncodedString()

            // Manually construct the raw JSON string
            let jsonString = """
            {"audio_data":"\(audioBase64)", "model_name":"\(modelName)", "session_id":"\(sessionID)", "prompt_duration":\(promptDuration)}
            """

            print("Sending continue_music_request with raw JSON string: \(jsonString)")

            // Send the raw JSON string to Socket.IO
            socket?.emit("continue_music_request", jsonString)
        } catch {
            print("Error reading processed audio data: \(error)")
        }
    }
    
    func getLastProcessedAudioURL() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            let audioFiles = files.filter { $0.lastPathComponent.hasPrefix("processedAudio_") && $0.pathExtension == "wav" }
            let sortedFiles = try audioFiles.sorted {
                let attr1 = try $0.resourceValues(forKeys: [.creationDateKey])
                let attr2 = try $1.resourceValues(forKeys: [.creationDateKey])
                return attr1.creationDate ?? Date.distantPast > attr2.creationDate ?? Date.distantPast
            }
            return sortedFiles.first
        } catch {
            print("Error retrieving processed audio files: \(error)")
            return nil
        }
    }
    
    func retryMusic(modelName: String, promptDuration: Int) {
        guard socket?.status == .connected else {
            print("Socket is not connected")
            return
        }

        guard let sessionID = sessionID else {
            print("No session ID available")
            return
        }

        // Manually construct the raw JSON string
        let jsonString = """
        {"session_id":"\(sessionID)", "model_name":"\(modelName)", "prompt_duration":\(promptDuration)}
        """

        print("Sending retry_music_request with raw JSON string: \(jsonString)")

        // Send the raw JSON string to Socket.IO
        socket?.emit("retry_music_request", jsonString)
    }
    
    func updateCroppedAudio(audioBase64: String) {
        guard socket?.status == .connected else {
            print("Socket is not connected")
            return
        }

        guard let sessionID = sessionID else {
            print("No session ID available")
            return
        }

        // Manually construct the raw JSON string
        let jsonString = """
        {"audio_data":"\(audioBase64)", "session_id":"\(sessionID)"}
        """

        print("Sending update_cropped_audio with raw JSON string: \(jsonString)")

        // Send the raw JSON string to Socket.IO
        socket?.emit("update_cropped_audio", jsonString)
    }


    func closeSocketConnection() {
        socket?.disconnect()
        isConnected = false
    }
}
