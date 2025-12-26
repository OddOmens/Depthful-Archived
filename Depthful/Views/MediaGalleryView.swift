import SwiftUI

struct MediaGalleryView: View {
    @Environment(\.dismiss) var dismiss
    let thought: Thought
    @State private var selectedImageForViewing: UIImage?
    @State private var showingImageViewer = false
    
    private var images: [UIImage] {
        if let imageData = thought.images,
           let images = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: imageData) as? [UIImage] {
            return images
        }
        return []
    }
    
    private var recordings: [VoiceRecording] {
        let request = VoiceRecording.fetchRequest()
        request.predicate = NSPredicate(format: "thought == %@", thought)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \VoiceRecording.createdAt, ascending: false)]
        
        do {
            return try thought.managedObjectContext?.fetch(request) ?? []
        } catch {
            print("Failed to fetch recordings: \(error)")
            return []
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !images.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photos".localized)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
                            ], spacing: 12) {
                                ForEach(images.indices, id: \.self) { index in
                                    Image(uiImage: images[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.colorStroke, lineWidth: 1)
                                        )
                                        .onTapGesture {
                                            selectedImageForViewing = images[index]
                                            showingImageViewer = true
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    if !recordings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Voice Recordings".localized)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(recordings, id: \.id) { recording in
                                AudioPlayerView(recording: recording)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Media Gallery".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image("arrow-down")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                }
            }
            .sheet(isPresented: $showingImageViewer) {
                if let image = selectedImageForViewing {
                    FullImageViewer(
                        images: images,
                        initialIndex: images.firstIndex(of: image) ?? 0,
                        isPresented: $showingImageViewer,
                        onDelete: { _ in }
                    )
                }
            }
        }
    }
} 