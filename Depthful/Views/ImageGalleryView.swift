import SwiftUI
import PhotosUI

// CRITICAL: Add image compression and resizing to prevent memory crashes
extension UIImage {
    func resizedForDisplay(maxDimension: CGFloat = 1200) -> UIImage? {
        let size = self.size
        
        // Calculate new size maintaining aspect ratio
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        if scale >= 1 { return self } // Don't upscale
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // Use UIGraphicsImageRenderer for memory efficiency
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    func compressedForStorage(quality: CGFloat = 0.85) -> Data? {
        return self.jpegData(compressionQuality: quality)
    }
}

struct ImageGalleryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let thought: Thought
    @State private var images: [UIImage] = [] {
        didSet {
            print("DEBUG: images array changed - new count: \(images.count)")
        }
    }
    @State private var showingImagePicker = false
    @State private var hasChanges = false
    @AppStorage("imageGalleryState") private var statePreservationToken = UUID().uuidString
    
    var body: some View {
        let _ = print("DEBUG: Body rebuilding - images.count: \(images.count)")
        
        return VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if images.isEmpty {
                        VStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(Color.gray.opacity(0.3))
                                
                            
                            Text("No photos yet".localized)
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                Text("Add Photos".localized)
                                    .foregroundColor(Color.colorPrimary)
                                    .padding(.top, 12)
                            }
                        }
                        .frame(minHeight: UIScreen.main.bounds.height * 0.7)
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 180, maximum: 200), spacing: 0)
                        ], spacing: 0) {
                            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                                NavigationLink(destination: {
                                    FullImageViewer(
                                        images: images,
                                        initialIndex: index,
                                        isPresented: .constant(true),
                                        onDelete: { imageToDelete in
                                            // The FullImageViewer has already removed the image from its local array
                                            // We need to remove it from the parent's images array and save to Core Data
                                            if let deleteIndex = images.firstIndex(of: imageToDelete) {
                                                images.remove(at: deleteIndex)

                                                if images.isEmpty {
                                                    // Persist empty state by clearing Core Data field
                                                    do {
                                                        if let existingThought = viewContext.object(with: thought.objectID) as? Thought {
                                                            existingThought.images = nil
                                                            existingThought.lastUpdated = Date()
                                                            try viewContext.save()
                                                            hasChanges = false
                                                            print("Deleted last image and cleared Core Data images field")
                                                        }
                                                    } catch {
                                                        print("Error clearing images after last deletion: \(error)")
                                                    }
                                                } else {
                                                    // Save remaining images
                                                    saveImages(images)
                                                    hasChanges = false // Reset since we just saved
                                                    print("Deleted image from gallery, \(images.count) remaining")
                                                }
                                            }
                                        }
                                    )
                                    .navigationBarHidden(true)
                                }) {
                                    // Use resized image for display to prevent memory issues
                                    let displayImage = image.resizedForDisplay(maxDimension: 800) ?? image
                                    Image(uiImage: displayImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width / 2, height: UIScreen.main.bounds.width / 2)
                                        .clipped()
                                        .contentShape(Rectangle())
                                        
                                }
                            }
                        }
                        .padding(0)
                    }
                }
                .padding(.vertical)
            }
            .id(statePreservationToken)
        }
        .navigationTitle("Photos".localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if hasChanges {
                        saveImages(images)
                    }
                    dismiss()
                }) {
                    Image("arrow-left")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color.colorPrimary)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        
                }
            }
            
            if !images.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingImagePicker = true
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
        .fullScreenCover(isPresented: $showingImagePicker) {
            NavigationStack {
                ImagePicker(images: $images)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                showingImagePicker = false
                                if !images.isEmpty {
                                    saveImages(images)
                                    hasChanges = true
                                }
                            }) {
                                Text("Done".localized)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.colorPrimary)
                            }
                        }
                    }
            }
            .horizontalSlideTransition()
            .animation(.easeInOut(duration: 0.3), value: showingImagePicker)
            .onDisappear {
                if !images.isEmpty {
                    saveImages(images)
                    hasChanges = true
                }
            }
        }
        .onAppear {
            print("DEBUG: ImageGalleryView appeared")
            loadImages()
        }
        .onDisappear {
            print("ImageGalleryView disappeared")
            if hasChanges {
                saveImages(images)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("App will resign active - ImageGalleryView")
            statePreservationToken = UUID().uuidString // Update token to preserve state
            if hasChanges || !images.isEmpty {
                saveImages(images)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            print("App will terminate - ImageGalleryView")
            if hasChanges || !images.isEmpty {
                saveImages(images)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            print("App did enter background - ImageGalleryView")
            if hasChanges || !images.isEmpty {
                saveImages(images)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("App did become active - ImageGalleryView")
            loadImages()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            print("⚠️ Memory warning received - forcing garbage collection")
            // Force garbage collection without limiting images
            viewContext.refreshAllObjects()
        }
    }
    
    private func loadImages() {
        print("DEBUG: Starting loadImages()")
        print("Loading images for thought: \(thought.objectID)")
        
        // Refresh the thought object to get the latest state from Core Data
        viewContext.refresh(thought, mergeChanges: false)
        
        if let imageData = thought.images {
            // Try the data array method first (matches the saving format)
            do {
                if let imageDataArray = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSData.self], from: imageData) as? [Data] {
                    images = imageDataArray.compactMap { UIImage(data: $0) }
                    print("Loaded \(images.count) images (data array method)")
                    
                    // Check for potentially low-quality images
                    checkImageQuality(imageDataArray)
                    return
                }
            } catch {
                print("Failed to load images using data array method: \(error)")
            }
            
            // Try the secure NSKeyedUnarchiver method if first method failed
            do {
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: imageData)
                unarchiver.requiresSecureCoding = true
                
                if let imageDataArray = unarchiver.decodeObject(of: [NSArray.self, NSData.self], forKey: "images") as? [Data] {
                    images = imageDataArray.compactMap { UIImage(data: $0) }
                    print("Loaded \(images.count) images (secure data array method)")
                    
                    // Check for potentially low-quality images
                    checkImageQuality(imageDataArray)
                    return
                }
            } catch {
                print("Failed to load images using secure data array method: \(error)")
            }
            
            // Fall back to legacy format
            if let savedImages = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: imageData) as? [UIImage] {
                images = savedImages
                print("Loaded \(images.count) images (legacy method)")
                print("⚠️ Legacy images detected - may have quality issues")
            }
        } else {
            // No image data, clear the images array
            images = []
            print("No image data found, cleared images array")
        }
        
        // Reset hasChanges after loading
        hasChanges = false
    }
    
    private func checkImageQuality(_ imageDataArray: [Data]) {
        let lowQualityCount = imageDataArray.filter { data in
            // Rough estimate: if compressed data is very small relative to expected size,
            // it might be heavily compressed
            return data.count < 50000 // Less than 50KB might indicate heavy compression
        }.count
        
        if lowQualityCount > 0 {
            print("⚠️ Detected \(lowQualityCount) potentially low-quality images that may have artifacts")
            print("💡 Consider re-adding these images from your photo library for better quality")
        }
    }
    
    private func saveImages(_ processedImages: [UIImage]) {
        print("DEBUG: Starting saveImages() with \(processedImages.count) images")
        print("Saving \(processedImages.count) images")
        
        if processedImages.isEmpty {
            do {
                if let existingThought = viewContext.object(with: thought.objectID) as? Thought {
                    existingThought.images = nil
                    existingThought.lastUpdated = Date()
                    try viewContext.save()
                    hasChanges = false
                    print("Saved empty images array: cleared Core Data images field")
                }
            } catch {
                print("Error saving empty images state: \(error)")
            }
            return
        }
        
        do {
            // Use the new compression method
            let imageDataArray = processedImages.compactMap { image in
                return image.compressedForStorage(quality: 0.85) // Higher quality for better storage
            }
            
            if !imageDataArray.isEmpty {
                let archiver = NSKeyedArchiver(requiringSecureCoding: true)
                archiver.encode(imageDataArray as NSArray, forKey: "images")
                let imageData = archiver.encodedData
                
                // Get the thought from its context to avoid issues
                if let existingThought = viewContext.object(with: thought.objectID) as? Thought {
                    existingThought.images = imageData
                    existingThought.lastUpdated = Date()
                    
                    try viewContext.save()
                    hasChanges = false
                    print("Images saved successfully with compression")
                }
            }
        } catch {
            print("Error saving images: \(error)")
        }
    }
}

// Update FullImageViewer to work with navigation
struct FullImageViewer: View {
    @State private var images: [UIImage]
    let initialIndex: Int
    @Binding var isPresented: Bool
    var onDelete: (UIImage) -> Void
    @State private var currentIndex: Int
    @State private var showingDeleteConfirmation = false
    @State private var offset: CGFloat = 0
    @State private var dragging = false
    @Environment(\.dismiss) private var dismiss
    
    init(images: [UIImage], initialIndex: Int, isPresented: Binding<Bool>, onDelete: @escaping (UIImage) -> Void) {
        print("DEBUG: FullImageViewer init - images: \(images.count), initialIndex: \(initialIndex)")
        self._images = State(initialValue: images)
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self.onDelete = onDelete
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        let _ = print("DEBUG: FullImageViewer body rebuilding - currentIndex: \(currentIndex), initialIndex: \(initialIndex)")
        
        return GeometryReader { geometry in
            VStack(spacing: 0) {
                // Navigation Bar
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image("arrow-left")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            
                    }
                    Spacer()
                    Text("Image \(currentIndex + 1) of \(images.count)".localized)
                        .font(.headline)
                    Spacer()
                    if !images.isEmpty {
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
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Image Viewer
                if !images.isEmpty && images.indices.contains(currentIndex) {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .tag(index)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            dragging = true
                                            offset = value.translation.width
                                        }
                                        .onEnded { value in
                                            dragging = false
                                            let threshold: CGFloat = 50
                                            withAnimation {
                                                if value.translation.width > threshold && currentIndex > 0 {
                                                    currentIndex -= 1
                                                } else if value.translation.width < -threshold && currentIndex < images.count - 1 {
                                                    currentIndex += 1
                                                }
                                                offset = 0
                                            }
                                        }
                                )
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        print("DEBUG: TabView onAppear - setting currentIndex to \(initialIndex)")
                        currentIndex = initialIndex
                    }
                } else {
                    Text("No images available".localized)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .alert("Delete Photo", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if images.indices.contains(currentIndex) {
                        let wasLastImage = images.count == 1
                        let imageToDelete = images[currentIndex]
                        
                        // Remove from local images array first
                        images.remove(at: currentIndex)
                        
                        // Call the onDelete callback to update the parent
                        onDelete(imageToDelete)
                        
                        // Navigate back if this was the last image
                        if wasLastImage {
                            dismiss()
                        } else {
                            // Adjust currentIndex if we deleted the last image in the array
                            if currentIndex >= images.count && currentIndex > 0 {
                                currentIndex = images.count - 1
                            }
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this photo?".localized)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
        }
    }
} 

