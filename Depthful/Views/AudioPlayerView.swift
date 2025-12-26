import SwiftUI
import AVFoundation
import Speech
import CoreData

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    private var timer: Timer?
    private var wasInterrupted = false
    private var wasPlayingBeforeInterruption = false
    
    override init() {
        super.init()
        setupNotifications()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        // Handle interruption start
        if type == .began {
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                wasInterrupted = true
                pausePlayback()
            }
        }
        // Handle interruption end
        else if type == .ended {
            if wasInterrupted && wasPlayingBeforeInterruption,
               let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                resumePlayback()
                wasInterrupted = false
            }
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Handle route changes that might affect playback
        switch reason {
        case .oldDeviceUnavailable:
            // Automatically pause when headphones are unplugged
            if isPlaying {
                pausePlayback()
            }
        case .newDeviceAvailable, .categoryChange:
            // Try to reactivate audio session
            try? AVAudioSession.sharedInstance().setActive(true)
        default:
            break
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPlayback()
    }
    
    func startPlayback(audioData: Data) {
        stopPlayback()
        
        // Set up notifications for interruptions
        setupNotifications()
        
        do {
            // Configure audio session
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers, .allowBluetoothA2DP])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to set audio session category: \(error)")
            }
            
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // Increase volume to maximum
            audioPlayer?.volume = 1.0
            
            duration = audioPlayer?.duration ?? 0
            startTimer()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Failed to initialize audio player: \(error)")
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func resumePlayback() {
        // Check if audio session is still active
        do {
            if !AVAudioSession.sharedInstance().isOtherAudioPlaying {
                try AVAudioSession.sharedInstance().setActive(true)
            }
        } catch {
            print("Failed to reactivate audio session: \(error)")
        }
        
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        stopTimer()
        
        // Deactivate audio session when done
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    private func startTimer() {
        // Stop any existing timer first
        stopTimer()
        
        // Create a new timer without capturing self weakly
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Since Timer retains self, but we know the timer will be invalidated
            // appropriately in stopTimer(), this is safe
            if let player = self.audioPlayer {
                self.currentTime = player.currentTime
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        currentTime = 0
    }
}

class TranscriptionManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    @Published var transcription: String = ""
    @Published var isTranscribing = false
    @Published var isTranscriptionAvailable = false
    private var cleanupWorkItem: DispatchWorkItem?
    var onTranscriptionComplete: ((String) -> Void)? = nil
    
    // Add a cleanup step to ensure we release resources
    deinit {
        print("TranscriptionManager deinit called")
        cleanupResources()
    }
    
    private func cleanupResources() {
        // Cancel any previous cleanup
        cleanupWorkItem?.cancel()
        
        // Reset task first
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Reset engine
        audioEngine?.stop()
        audioEngine = nil
        
        // Create a new cleanup work item for async operations
        let workItem = DispatchWorkItem { [weak self] in
            // Only update properties if self still exists
            if let self = self {
                self.isTranscribing = false
            }
        }
        
        // Store reference to work item
        cleanupWorkItem = workItem
        
        // Execute cleanup on main thread
        DispatchQueue.main.async(execute: workItem)
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
    
    func transcribeAudio(from audioData: Data) {
        // Cancel any previous operations and clean up resources
        cancelTranscription()
        
        // Set flags
        isTranscribing = true
        transcription = "" // Clear any previous transcription
        
        // Check authorization
        guard speechRecognizer?.isAvailable == true else {
            print("Speech recognizer is not available")
            isTranscribing = false
            return
        }
        
        // Create a unique filename with UUID
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueID = UUID().uuidString
        let tempFile = tempDir.appendingPathComponent("\(uniqueID).m4a")
        
        // Create a separate queue for file operations
        let fileQueue = DispatchQueue(label: "com.oddOmens.depthful.fileOperations", qos: .userInitiated)
        
        // Execute file operations on the dedicated queue
        fileQueue.async {
            do {
                // Write the audio data to the temporary file
                try audioData.write(to: tempFile)
                
                // Return to main thread for recognition
                DispatchQueue.main.async {
                    // Create recognition request
                    let request = SFSpeechURLRecognitionRequest(url: tempFile)
                    request.shouldReportPartialResults = true
                    
                    // Weak reference to self to break potential retain cycles
                    weak var weakSelf = self
                    
                    // Start recognition task
                    self.recognitionTask = self.speechRecognizer?.recognitionTask(with: request) { result, error in
                        // Get strong reference if still available
                        guard let strongSelf = weakSelf else {
                            // Clean up temp file if self is gone
                            try? FileManager.default.removeItem(at: tempFile)
                            return
                        }
                        
                        var isFinal = false
                        
                        // Handle the result
                        if let result = result {
                            DispatchQueue.main.async {
                                // Check again if self is still available
                                guard let strongSelf = weakSelf else { return }
                                strongSelf.transcription = result.bestTranscription.formattedString
                                strongSelf.isTranscriptionAvailable = true
                                
                                // Notify with callback when we have a final result
                                if result.isFinal {
                                    strongSelf.onTranscriptionComplete?(strongSelf.transcription)
                                }
                            }
                            isFinal = result.isFinal
                        } else if let error = error {
                            // Handle speech recognition error
                            print("Speech recognition error: \(error.localizedDescription)")
                            // If no valid transcription was found, complete with empty string
                            DispatchQueue.main.async {
                                strongSelf.isTranscriptionAvailable = true  // Mark as available even if empty
                                strongSelf.onTranscriptionComplete?("")
                            }
                        }
                        
                        // Handle completion
                        if error != nil || isFinal {
                            DispatchQueue.main.async {
                                // Check again if self is still available
                                guard let strongSelf = weakSelf else { return }
                                strongSelf.isTranscribing = false
                            }
                            
                            // Clean up temp file
                            try? FileManager.default.removeItem(at: tempFile)
                        }
                    }
                }
            } catch {
                print("Error preparing audio for transcription: \(error)")
                DispatchQueue.main.async {
                    // Update the state on main thread - no need to check self since we're in a closure
                    self.isTranscribing = false
                    self.isTranscriptionAvailable = true  // Mark as available
                    self.onTranscriptionComplete?("")  // Complete with empty result on error
                }
                
                // Clean up temp file in case of error
                try? FileManager.default.removeItem(at: tempFile)
            }
        }
    }
    
    func cancelTranscription() {
        cleanupResources()
    }
}

struct AudioPlayerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var transcriptionManager = TranscriptionManager()
    @State private var isEditingTitle = false
    @State private var recordingTitle: String
    @State private var showingDeleteConfirmation = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showTranscription = false
    @State private var hasRequestedTranscription = false
    @State private var showTranscriptionCopiedToast = false
    @State private var transcriptionButtonState: TranscriptionButtonState = .notRequested

    let recording: VoiceRecording
    var onDelete: (() -> Void)?
    
    enum TranscriptionButtonState {
        case notRequested
        case requested
        case transcribing
        case available
    }
    
    init(recording: VoiceRecording, onDelete: (() -> Void)? = nil) {
        self.recording = recording
        self.onDelete = onDelete
        _recordingTitle = State(initialValue: recording.name ?? "Untitled Recording")
        
        // Check if there's already a transcription in the recording
        if let existingTranscription = recording.transcription, !existingTranscription.isEmpty {
            _hasRequestedTranscription = State(initialValue: true)
            _transcriptionButtonState = State(initialValue: .available)
            _showTranscription = State(initialValue: false) // Set to false initially
        }
    }
    
    private var formattedCurrentTime: String {
        formatTime(audioPlayer.currentTime)
    }
    
    private var formattedDuration: String {
        formatTime(audioPlayer.duration)
    }
    
    private var progress: Double {
        guard audioPlayer.duration > 0 else { return 0 }
        return audioPlayer.currentTime / audioPlayer.duration
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func updateRecordingName() {
        // Get the recording from the context to avoid any potential issues
        if let recordingToUpdate = viewContext.object(with: recording.objectID) as? VoiceRecording {
            recordingToUpdate.name = recordingTitle
            
            do {
                try viewContext.save()
                print("Successfully updated recording name to: \(recordingTitle)")
            } catch {
                print("Failed to update recording name: \(error)")
            }
        }
    }
    
    private func deleteRecording() {
        audioPlayer.stopPlayback()
        transcriptionManager.cancelTranscription()
        viewContext.delete(recording)
        
        do {
            try viewContext.save()
            // Call the onDelete callback to refresh the list
            onDelete?()
        } catch {
            print("Failed to delete recording: \(error)")
        }
    }
    
    private func requestTranscription() {
        // If already has transcription, toggle visibility
        if hasRequestedTranscription && !transcriptionManager.isTranscribing {
            showTranscription.toggle()
            return
        }
        
        // First, make a local copy of the audio data to avoid Core Data threading issues
        guard let audioData = recording.audioData else {
            errorMessage = "No audio data available for transcription."
            showingErrorAlert = true
            return
        }
        
        // Check if we already have a saved transcription
        if let existingTranscription = recording.transcription, !existingTranscription.isEmpty {
            // Use existing transcription
            transcriptionManager.transcription = existingTranscription
            transcriptionManager.isTranscriptionAvailable = true
            hasRequestedTranscription = true
            showTranscription = true
            transcriptionButtonState = .available
            return
        }
        
        // Update UI state
        transcriptionButtonState = .requested
        
        // Set callback for transcription completion
        transcriptionManager.onTranscriptionComplete = { transcription in
            // Always mark as available regardless of whether there's content
            self.hasRequestedTranscription = true
            self.showTranscription = true
            self.transcriptionButtonState = .available
            
            // Save transcription to CoreData (even if empty)
                if let recordingToUpdate = self.viewContext.object(with: self.recording.objectID) as? VoiceRecording {
                    recordingToUpdate.transcription = transcription
                    try? self.viewContext.save()
            }
        }
        
        // Create a separate copy of the data to avoid Core Data issues
        let audioDataCopy = Data(audioData)
        
        // Request permission and start transcription
        transcriptionManager.requestPermission { granted in
            if granted {
                // Start transcribing with the copied data
                DispatchQueue.main.async {
                    self.transcriptionButtonState = .transcribing
                }
                transcriptionManager.transcribeAudio(from: audioDataCopy)
                
                // Add a timeout in case the transcription doesn't complete
                // (often happens with empty audio or no speech detected)
                DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                    if self.transcriptionButtonState == .transcribing || self.transcriptionButtonState == .requested {
                        // If still processing after 15 seconds, mark as complete with empty result
                        self.transcriptionManager.onTranscriptionComplete?("")
                    }
                }
                
                // Update UI state on main thread
                DispatchQueue.main.async {
                    self.showTranscription = true
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Speech recognition permission is required for transcription."
                    self.showingErrorAlert = true
                    self.transcriptionButtonState = .notRequested
                }
            }
        }
    }
    
    private func copyTranscriptionToClipboard() {
        let textToCopy = transcriptionManager.isTranscriptionAvailable ? 
            transcriptionManager.transcription : 
            (recording.transcription ?? "")
            
        UIPasteboard.general.string = textToCopy
        showTranscriptionCopiedToast = true
        
        // Hide toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showTranscriptionCopiedToast = false
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                // Title section
                HStack {
                    if isEditingTitle {
                        HStack(spacing: 8) {
                            Button(action: {
                                isEditingTitle = false
                                updateRecordingName()
                            }) {
                                Image("memo-check")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(Color.colorPrimary)
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                            }
                            
                            TextField("Recording Name".localized, text: $recordingTitle, onCommit: {
                                isEditingTitle = false
                                updateRecordingName()
                            })
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Button(action: {
                                isEditingTitle = true
                            }) {
                                Image("memo-pencil")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(Color.colorPrimary)
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                            }
                            
                            Text(recordingTitle)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Spacer()
                    
                    // Delete button moved inline
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image("trash")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.red)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                }
                .padding(.bottom, 12)
                
                // Play/Pause button and waveform section - made into a fixed height container
                HStack(spacing: 12) {
                    Button(action: {
                        if audioPlayer.isPlaying {
                            audioPlayer.pausePlayback()
                        } else if audioPlayer.currentTime > 0 {
                            audioPlayer.resumePlayback()
                        } else if let audioData = recording.audioData {
                            audioPlayer.startPlayback(audioData: audioData)
                        } else {
                            errorMessage = "Unable to play recording: No audio data available"
                            showingErrorAlert = true
                        }
                    }) {
                        Image(audioPlayer.isPlaying ? "circle-pause" : "circle-play")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                    }
                    
                    VStack(spacing: 8) {
                        // Waveform
                        AudioWaveformView(isPlaying: audioPlayer.isPlaying, progress: progress)
                            .frame(height: 30)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let width = value.location.x
                                        let totalWidth = UIScreen.main.bounds.width - 100 // Approximate total width
                                        let progress = max(0, min(1, width / totalWidth))
                                        audioPlayer.seek(to: progress * audioPlayer.duration)
                                    }
                            )
                        
                        // Progress bar with times at ends
                        HStack(spacing: 0) {
                            // Current time
                            Text(formattedCurrentTime)
                                .monospacedDigit()
                                .foregroundColor(.gray)
                                .font(.caption)
                                .frame(width: 40, alignment: .leading) // Fixed width
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 2)
                                    
                                    Rectangle()
                                        .fill(Color.colorPrimary)
                                        .frame(width: geometry.size.width * progress, height: 2)
                                    
                                    // Drag handle
                                    Circle()
                                        .fill(Color.colorPrimary)
                                        .frame(width: 10, height: 10)
                                        .offset(x: (geometry.size.width * progress) - 5)
                                }
                            }
                            .padding(.horizontal, 8)
                            
                            // Duration
                            Text(formattedDuration)
                                .monospacedDigit()
                                .foregroundColor(.gray)
                                .font(.caption)
                                .frame(width: 40, alignment: .trailing) // Fixed width
                        }
                    }
                }
                .frame(height: 80) // Fixed height container
                .padding(.bottom, 8) // Consistent padding
                
                // Divider to separate player from transcription
                Divider()
                    .padding(.vertical, 4)
                
                // Fixed-height container for transcription
                VStack(spacing: 0) {
                    // Transcription button with states
                    HStack {
                        Button(action: requestTranscription) {
                            HStack(spacing: 6) {
                                switch transcriptionButtonState {
                                case .notRequested:
                                    Image("annotation")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(Color.colorPrimary)
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                    Text("Transcribe Audio".localized)
                                        .font(.subheadline)
                                        .foregroundColor(Color.colorPrimary)
                                    
                                case .requested, .transcribing:
                                    if transcriptionManager.isTranscribing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .colorPrimary))
                                            .frame(width: 22, height: 22)
                                        Text("Transcribing...".localized)
                                            .font(.subheadline)
                                            .foregroundColor(Color.colorPrimary)
                                    } else {
                                        Image("annotation")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                        Text("Processing...".localized)
                                            .font(.subheadline)
                                            .foregroundColor(Color.colorPrimary)
                                    }
                                    
                                case .available:
                                    Image("annotation")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(Color.colorPrimary)
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                    // Restore toggle functionality
                                    Text(showTranscription ? "Hide Transcription".localized : "Show Transcription".localized)
                                        .font(.subheadline)
                                        .foregroundColor(Color.colorPrimary)
                                }
                            }
                        }
                        .disabled(transcriptionButtonState == .transcribing)
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.vertical, 6)
                        
                        Spacer()
                        
                        // Always show copy button when transcription is available
                        if transcriptionButtonState == .available {
                            Button(action: copyTranscriptionToClipboard) {
                                HStack(spacing: 6) {
                                    Image("copy")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(Color.colorPrimary)
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                    Text("Copy".localized)
                                        .font(.caption)
                                        .foregroundColor(.colorPrimary)
                                }
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    
                    // Transcription content with toggle functionality
                    if transcriptionButtonState == .available && showTranscription {
                        VStack(alignment: .leading, spacing: 4) {
                            let displayText = transcriptionManager.isTranscriptionAvailable ? 
                                transcriptionManager.transcription : 
                                (recording.transcription ?? "")
                            
                            ScrollView {
                                if displayText.isEmpty {
                                    Text("Nothing to transcribe".localized)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(10)
                                } else {
                                Text(displayText)
                                    .font(.footnote)
                                    .lineSpacing(3)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                }
                            }
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .onTapGesture {
                                copyTranscriptionToClipboard()
                            }
                        }
                        .padding(.top, 4)
                    } 
                    else if transcriptionManager.isTranscribing {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Processing transcription...".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                    }
                }
                .background(Color.clear)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    // Light mode background
                    Color(UIColor.systemGray5)
                        .opacity(0.1)
                        .environment(\.colorScheme, .light)
                    
                    // Dark mode background
                    Color(UIColor.systemGray5)
                        .opacity(0.1)
                        .environment(\.colorScheme, .dark)
                }
            )
            .cornerRadius(16)
            .padding(.horizontal)
            .padding(.vertical, 4)
            .onDisappear {
                // Clean up resources when view disappears
                audioPlayer.stopPlayback()
                transcriptionManager.cancelTranscription()
                transcriptionManager.onTranscriptionComplete = nil
                
                // Save transcription if available
                if transcriptionManager.isTranscriptionAvailable && !transcriptionManager.transcription.isEmpty {
                    // Get the recording from the current context to update
                    if let recordingToUpdate = viewContext.object(with: recording.objectID) as? VoiceRecording {
                        recordingToUpdate.transcription = transcriptionManager.transcription
                        try? viewContext.save()
                    }
                }
                
                // Reset state to avoid retain cycles
                showTranscription = false
            }
            .onAppear {
                // Initialize transcription manager with existing transcription if available
                if let existingTranscription = recording.transcription, !existingTranscription.isEmpty {
                    transcriptionManager.transcription = existingTranscription
                    transcriptionManager.isTranscriptionAvailable = true
                    transcriptionButtonState = .available
                    showTranscription = false // Keep hidden by default
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isEditingTitle)
            .onChange(of: transcriptionManager.isTranscribing) { _, newValue in
                if newValue {
                    transcriptionButtonState = .transcribing
                }
            }
            .onChange(of: transcriptionManager.isTranscriptionAvailable) { _, newValue in
                if newValue {
                    hasRequestedTranscription = true 
                    showTranscription = false // Keep hidden by default
                    transcriptionButtonState = .available
                }
            }
            .alert("Delete Recording".localized, isPresented: $showingDeleteConfirmation) {
                Button("Cancel".localized, role: .cancel) { }
                Button("Delete".localized, role: .destructive) {
                    deleteRecording()
                }
            } message: {
                Text("Are you sure you want to delete this recording? This action cannot be undone.".localized)
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            
            // Toast notification for copying
            if showTranscriptionCopiedToast {
                HStack(spacing: 8) {
                    Image("circle-check-alt")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.green)
                        .frame(width: 20, height: 20)
                    Text("Transcription copied to clipboard".localized)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.8))
                )
                .padding(.bottom, 30)
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
                .animation(.spring(), value: showTranscriptionCopiedToast)
            }
        }
    }
} 
