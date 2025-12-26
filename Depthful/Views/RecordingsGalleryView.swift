import SwiftUI
import CoreData



struct RecordingsGalleryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    let thought: Thought
    @State private var recordings: [VoiceRecording] = []
    @State private var showingVoiceRecorder = false
    @State private var hasChanges = false
    @AppStorage("recordingsGalleryState") private var statePreservationToken = UUID().uuidString
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if recordings.isEmpty {
                        VStack {
                            Image("waveform")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color.gray.opacity(0.3))
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                
                            
                            Text("No recordings yet".localized)
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                showingVoiceRecorder = true
                            }) {
                                Text("Record Voice".localized)
                                    .foregroundColor(Color.colorPrimary)
                                    .padding(.top, 12)
                            }
                        }
                        .frame(minHeight: UIScreen.main.bounds.height * 0.7)
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(recordings, id: \.id) { recording in
                            AudioPlayerView(recording: recording) {
                                loadRecordings()
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .id(statePreservationToken) // Preserve state with a unique ID
        }
        .navigationTitle("Voice Recordings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    saveContext()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image("arrow-left")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color.colorPrimary)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        
                }
            }
            
            if !recordings.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingVoiceRecorder = true
                    }) {
                        Image("plus")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            
                    }
                }
            }
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            NavigationStack {
                VoiceRecorderView(thought: thought)
                    .environment(\.managedObjectContext, viewContext)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .onDisappear {
                loadRecordings()
            }
        }
        .onAppear {
            print("RecordingsGalleryView appeared")
            loadRecordings()
        }
        .onDisappear {
            print("RecordingsGalleryView disappeared")
            saveContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("App will resign active - RecordingsGalleryView")
            statePreservationToken = UUID().uuidString // Update token to preserve state
            saveContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            print("App will terminate - RecordingsGalleryView")
            saveContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            print("App did enter background - RecordingsGalleryView")
            saveContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("App did become active - RecordingsGalleryView")
            loadRecordings()
        }
    }
    
    private func saveContext() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                print("Context saved successfully in RecordingsGalleryView")
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    private func loadRecordings() {
        print("Loading recordings for thought: \(thought.objectID)")
        let request = NSFetchRequest<VoiceRecording>(entityName: "VoiceRecording")
        request.predicate = NSPredicate(format: "thought == %@", thought)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \VoiceRecording.createdAt, ascending: false)]
        
        do {
            recordings = try viewContext.fetch(request)
            print("Loaded \(recordings.count) recordings")
        } catch {
            print("Error fetching recordings: \(error)")
            recordings = []
        }
    }
} 

