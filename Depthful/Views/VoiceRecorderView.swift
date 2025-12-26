import SwiftUI
import AVFoundation
import CoreData
import Speech

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentTime: TimeInterval = 0
    @Published var meterLevels: [Float] = Array(repeating: 0.05, count: 20) // For animated waveform
    private var timer: Timer?
    private var recordingURL: URL?
    private let maxRecordingDuration: TimeInterval = 300.0 // 5 minutes max
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .default)
            try audioSession?.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
        recordingURL = audioFilename
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 192000
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true // Enable metering for waveform
            audioRecorder?.record()
            isRecording = true
            isPaused = false
            startTimer()
            currentTime = 0
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        stopTimer()
    }
    
    func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        startTimer()
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        isPaused = false
        stopTimer()
        return recordingURL
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            
            // Update time
            self.currentTime = recorder.currentTime
            
            // Check if we've hit the max duration
            if self.currentTime >= self.maxRecordingDuration {
                let _ = self.stopRecording()
                return
            }
            
            // Update metering values for waveform
            recorder.updateMeters()
            
            // Get the power level and normalize it
            let powerLevel = recorder.averagePower(forChannel: 0)
            let normalizedLevel = self.normalizeSoundLevel(level: powerLevel)
            
            // Update the meter levels array for visualization (rolling window)
            self.meterLevels.removeFirst()
            self.meterLevels.append(normalizedLevel)
        }
    }
    
    private func normalizeSoundLevel(level: Float) -> Float {
        // Convert from -160dB to 0dB to a value between 0.05 and 1.0 for visualization
        let minDb: Float = -80.0
        let range: Float = 80.0
        
        // Clamp the value to our min/max range
        let clampedLevel = max(minDb, min(0, level))
        
        // Normalize to 0.0 - 1.0
        let normalized = 1.0 - ((clampedLevel - minDb) / range)
        
        // Scale to our desired range (0.05 - 1.0)
        return 0.05 + (normalized * 0.95)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        let _ = stopRecording()
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
}


struct LiveWaveformView: View {
    var meterLevels: [Float]
    var isRecording: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<meterLevels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.colorPrimary)
                    .frame(width: 6, height: CGFloat(meterLevels[index] * 70))
            }
        }
        .frame(height: 80)
        .padding(.vertical, 4)
        .padding(.horizontal)
    }
}

struct RecordButton: View {
    var isRecording: Bool
    var isPaused: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.15) : Color.colorPrimary.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Circle()
                    .fill(isRecording ? Color.red : Color.colorPrimary.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                if isRecording {
                    if isPaused {
                        Image("circle-play")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                    } else {
                        Image("circle-pause")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                    }
                } else {
                    Image("microphone-alt-1")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color.colorPrimary)
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                }
            }
        }
    }
}

struct VoiceRecorderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var transcriptionManager = TranscriptionManager()
    @State private var recordingName = ""
    @State private var showingSaveDialog = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingTranscriptionCopiedToast = false
    @State private var hasTranscriptionData = false
    @State private var showTranscriptionView = false
    @State private var transcriptionButtonState: TranscriptionButtonState = .hidden
    let thought: Thought?
    
    enum TranscriptionButtonState {
        case hidden
        case readyToTranscribe
        case transcribing
        case showingTranscription
    }
    
    private var formattedTime: String {
        let time = Int(audioRecorder.currentTime)
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var formattedMaxTime: String {
        return "5:00"
    }
    
    private var timeProgressPercentage: CGFloat {
        return CGFloat(min(audioRecorder.currentTime / 300.0, 1.0))
    }
    
    private func generateRecordingName() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "Recording \(formatter.string(from: Date()))"
    }
    
    private func saveRecording() {
        guard let url = audioRecorder.stopRecording() else {
            errorMessage = "No recording to save"
            showingErrorAlert = true
            return
        }
        
        // Get the thought from the current context to avoid cross-context issues
        var thoughtInCurrentContext: Thought?
        if let thought = thought {
            thoughtInCurrentContext = viewContext.object(with: thought.objectID) as? Thought
        }
        
        do {
            let audioData = try Data(contentsOf: url)
            let recording = VoiceRecording(context: viewContext)
            recording.id = UUID()
            recording.createdAt = Date()
            recording.name = recordingName.isEmpty ? generateRecordingName() : recordingName
            recording.audioData = audioData
            recording.duration = audioRecorder.currentTime
            recording.thought = thoughtInCurrentContext
            
            // If we have a transcription, save it
            if transcriptionManager.isTranscriptionAvailable {
                recording.transcription = transcriptionManager.transcription
            }
            
            try viewContext.save()
            
            // Clean up the temporary file
            try FileManager.default.removeItem(at: url)
            
            print("Successfully saved recording: \(recording.name ?? "Unknown")")
            dismiss()
        } catch {
            errorMessage = "Failed to save recording: \(error.localizedDescription)"
            showingErrorAlert = true
            print("Error saving recording: \(error)")
        }
    }
    
    private func handleRecordingAction() {
        if !audioRecorder.isRecording {
            // Start recording
            audioRecorder.startRecording()
        } else if audioRecorder.isPaused {
            // Resume recording
            audioRecorder.resumeRecording()
        } else {
            // Pause recording
            audioRecorder.pauseRecording()
        }
    }
    
    private func handleStopRecording() {
        // Stop recording first, then show save dialog
        if audioRecorder.currentTime > 0.5 {
            guard let url = audioRecorder.stopRecording() else {
                errorMessage = "No recording to save"
                showingErrorAlert = true
                return
            }
            
            // Set button state to ready for transcription
            transcriptionButtonState = .readyToTranscribe
            
            // Attempt to transcribe the audio before showing save dialog
            do {
                let audioData = try Data(contentsOf: url)
                transcribeAudio(audioData: audioData)
            } catch {
                print("Error preparing audio for transcription: \(error)")
            }
            
            showingSaveDialog = true
        } else {
            let _ = audioRecorder.stopRecording()
        }
    }
    
    private func transcribeAudio(audioData: Data) {
        // Update button state to transcribing
        transcriptionButtonState = .transcribing
        
        // Set the callback for when transcription completes
        transcriptionManager.onTranscriptionComplete = { transcription in
            // Update UI state immediately when transcription is available
            if !transcription.isEmpty {
                self.hasTranscriptionData = true
                self.showTranscriptionView = false // Set to false to hide by default
                self.transcriptionButtonState = .showingTranscription
            }
        }
        
        transcriptionManager.requestPermission { granted in
            if granted {
                transcriptionManager.transcribeAudio(from: audioData)
            } else {
                print("Speech recognition permission denied")
                // Reset state if permission denied
                DispatchQueue.main.async {
                    self.transcriptionButtonState = .readyToTranscribe
                }
            }
        }
    }
    
    private func copyTranscriptionToClipboard() {
        UIPasteboard.general.string = transcriptionManager.transcription
        showingTranscriptionCopiedToast = true
        
        // Hide the toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingTranscriptionCopiedToast = false
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 16) {
                Spacer()
                
                // Time display showing current / max duration
                HStack(alignment: .firstTextBaseline) {
                    Text(formattedTime)
                        .font(.system(size: 48, weight: .thin, design: .monospaced))
                        .foregroundColor(audioRecorder.isRecording ? .red : .primary)
                    
                    Text("/".localized)
                        .font(.system(size: 24, weight: .thin, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Text(formattedMaxTime)
                        .font(.system(size: 24, weight: .thin, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .frame(height: 60)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geometry.size.width * timeProgressPercentage, height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal)
                
                // Live waveform visualization with reduced height
                LiveWaveformView(
                    meterLevels: audioRecorder.meterLevels,
                    isRecording: audioRecorder.isRecording && !audioRecorder.isPaused
                )
                .frame(height: 80)
                
                // Recording controls
                HStack(spacing: 40) {
                    // Record/Pause button
                    RecordButton(
                        isRecording: audioRecorder.isRecording,
                        isPaused: audioRecorder.isPaused,
                        action: handleRecordingAction
                    )
                }
                
                // Always show save button but make it disabled until recording starts
                Button(action: {
                    if audioRecorder.isRecording || audioRecorder.isPaused {
                        let _ = audioRecorder.stopRecording()
                    }
                    // Auto-generate a name and save
                    recordingName = generateRecordingName()
                    saveRecording()
                }) {
                    Text("Finish and Save".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.colorPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .background(
                            // Change background color based on enabled state
                            audioRecorder.currentTime > 0.5 ? Color.colorSecondary : Color.colorSecondary.opacity(0.5)
                        )
                        .cornerRadius(30)
                }
                .disabled(audioRecorder.currentTime <= 0.5)
                .padding(.top, 10)
                
                // Use fixed height container for transcription UI to avoid content shifts
                ZStack(alignment: .topLeading) {
                    // Empty placeholder to maintain consistent layout
                    Color.clear
                        .frame(height: transcriptionButtonState == .showingTranscription ? 0 : 60)
                    
                    // Transcription section with improved transitions
                    VStack(spacing: 0) {
                        // Transcription button or status
                        switch transcriptionButtonState {
                        case .hidden:
                            EmptyView()
                            
                        case .readyToTranscribe:
                            Button(action: {
                                if let url = audioRecorder.stopRecording() {
                                    do {
                                        let audioData = try Data(contentsOf: url)
                                        transcribeAudio(audioData: audioData)
                                    } catch {
                                        print("Error preparing audio for transcription: \(error)")
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image("annotation")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.colorPrimary)
                                        .frame(width: 20, height: 20)
                                    Text("Transcribe Audio".localized)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.colorPrimary)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(Color.colorPrimary.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .transition(.opacity.combined(with: .scale))
                            
                        case .transcribing:
                            HStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .colorPrimary))
                                
                                Text("Transcribing audio...".localized)
                                    .font(.body)
                                    .foregroundColor(.colorPrimary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.colorPrimary.opacity(0.1))
                            .cornerRadius(8)
                            .transition(.opacity.combined(with: .scale))
                            
                        case .showingTranscription:
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Transcription".localized)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Button(action: copyTranscriptionToClipboard) {
                                        HStack(spacing: 6) {
                                            Image("copy")
                                                .resizable()
                                                .renderingMode(.template)
                                                .foregroundColor(.colorPrimary)
                                                .frame(width: 18, height: 18)
                                            Text("Copy".localized)
                                                .font(.subheadline)
                                                .foregroundColor(.colorPrimary)
                                        }
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                
                                // Transcription text with ScrollView to prevent cutting off
                                ScrollView {
                                    Text(transcriptionManager.transcription)
                                        .font(.footnote) // Even smaller font
                                        .lineSpacing(4) // Add some line spacing for readability
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true) // Allow height to expand
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                }
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .frame(minHeight: 80, maxHeight: .infinity) // Dynamic height
                                .onTapGesture {
                                    copyTranscriptionToClipboard()
                                }
                            }
                            .padding(.horizontal)
                            .transition(.opacity)
                        }
                    }
                    .animation(.spring(), value: transcriptionButtonState)
                }
                .frame(maxHeight: transcriptionButtonState == .showingTranscription ? 250 : 60)
                
                Spacer()
            }
            .padding()
            
        } .navigationTitle("New Recording".localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled() 
        .presentationDetents([.height(500), .large])
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if audioRecorder.isRecording || audioRecorder.isPaused {
                        let _ = audioRecorder.stopRecording()
                    }
                    dismiss()
                }) {
                    Image("xmark")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color.colorPrimary)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
            }
            
            // Add checkmark button to finish and save
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if audioRecorder.isRecording || audioRecorder.isPaused {
                        let _ = audioRecorder.stopRecording()
                    }
                    // Auto-generate a name and save
                    recordingName = generateRecordingName()
                    saveRecording()
                }) {
                    Image("circle-check-alt")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(audioRecorder.currentTime > 0.5 ? Color.colorPrimary : Color.colorPrimary.opacity(0.5))
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
                .disabled(audioRecorder.currentTime <= 0.5)
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            transcriptionManager.cancelTranscription()
            transcriptionManager.onTranscriptionComplete = nil
        }
        .onChange(of: transcriptionManager.isTranscribing) { _, newValue in
            if newValue {
                showTranscriptionView = false
                transcriptionButtonState = .transcribing
            }
        }
        .onChange(of: transcriptionManager.isTranscriptionAvailable) { _, newValue in
            if newValue {
                showTranscriptionView = false // Keep hidden by default
                transcriptionButtonState = .showingTranscription
            }
        }
        .onChange(of: audioRecorder.isRecording) { _, newValue in
            // When recording stops, show transcribe button if we have audio
            if !newValue && audioRecorder.currentTime > 0.5 && transcriptionButtonState == .hidden {
                transcriptionButtonState = .readyToTranscribe
            }
        }
        
        // Toast notification for copying
        if showingTranscriptionCopiedToast {
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
            .animation(.spring(), value: showingTranscriptionCopiedToast)
        }
    }
}

