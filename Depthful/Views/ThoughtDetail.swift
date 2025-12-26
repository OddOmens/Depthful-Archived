import SwiftUI
import CoreData
import UIKit
import StoreKit
import Charts // Import the Charts framework
import PhotosUI

// Markdown Text Editor with formatting toolbar
struct MarkdownTextEditor: View {
    @Binding var text: String
    @FocusState private var isTextEditorFocused: Bool
    @Binding var showingMarkdownPreview: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Text editor or preview
            if showingMarkdownPreview {
                ScrollView {
                    MarkdownRenderer(text: text)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(UIColor.systemBackground))
                .onTapGesture {
                    // Tap to return to edit mode
                    showingMarkdownPreview = false
                    isTextEditorFocused = true
                }
            } else {
                TextEditor(text: $text)
                    .focused($isTextEditorFocused)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingMarkdownPreview)
    }
    
    func insertMarkdown(_ prefix: String, _ suffix: String) {
        // For now, we'll use a simple approach since TextEditor doesn't easily expose selection
        // In a more advanced implementation, you'd use UITextView to get actual selection
        
        if text.isEmpty {
            text = prefix + "text" + suffix
        } else {
            // Check if we're at the end of the content
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text == trimmedText {
                // Add to the end with a space
                text += " " + prefix + "text" + suffix
            } else {
                // Add on a new line
                text += "\n" + prefix + "text" + suffix
            }
        }
    }
    
    func insertLink() {
        let linkMarkdown = "[Link Text](https://example.com)"
        if text.isEmpty {
            text = linkMarkdown
        } else {
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text == trimmedText {
                text += " " + linkMarkdown
            } else {
                text += "\n" + linkMarkdown
            }
        }
    }
}

// Format button component
struct FormatButton<Content: View>: View {
    let title: String
    let action: () -> Void
    let content: Content
    
    init(title: String, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            content
                .frame(minWidth: 30, minHeight: 30)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(6)
        }
    }
}

// Markdown renderer for preview
struct MarkdownRenderer: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseMarkdown(text), id: \.id) { element in
                renderElement(element)
            }
        }
    }
    
    private func renderElement(_ element: MarkdownElement) -> AnyView {
        switch element.type {
        case .paragraph:
            return AnyView(
                renderParagraph(element.children)
                    .padding(.bottom, 8)
            )
        default:
            // This shouldn't be called for top-level elements
            return AnyView(Text(""))
        }
    }
    
    private func renderParagraph(_ children: [MarkdownElement]) -> some View {
        // Build a single AttributedString to maintain inline flow
        var attributedString = AttributedString()
        
        for element in children {
            var elementString = AttributedString(element.content)
            
            switch element.type {
            case .text:
                // No additional formatting needed
                break
            case .bold:
                elementString.font = .body.bold()
            case .italic:
                elementString.font = .body.italic()
            case .underline:
                elementString.underlineStyle = .single
            case .code:
                elementString.font = .system(.body, design: .monospaced)
                elementString.foregroundColor = .secondary
            case .strikethrough:
                elementString.strikethroughStyle = .single
            case .link:
                elementString.foregroundColor = .blue
                elementString.underlineStyle = .single
                if let url = element.url {
                    elementString.link = URL(string: url)
                }
            default:
                // No additional formatting needed
                break
            }
            
            attributedString.append(elementString)
        }
        
        return Text(attributedString)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Markdown parsing structures
struct MarkdownElement {
    let id = UUID()
    let type: MarkdownType
    let content: String
    let url: String?
    let children: [MarkdownElement]
    
    init(type: MarkdownType, content: String, url: String? = nil, children: [MarkdownElement] = []) {
        self.type = type
        self.content = content
        self.url = url
        self.children = children
    }
}

enum MarkdownType {
    case text
    case bold
    case italic
    case underline
    case code
    case strikethrough
    case link
    case paragraph
}

// Simple markdown parser
func parseMarkdown(_ text: String) -> [MarkdownElement] {
    let paragraphs = text.components(separatedBy: "\n\n")
    return paragraphs.compactMap { paragraph in
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let elements = parseInlineMarkdown(trimmed)
        return MarkdownElement(type: .paragraph, content: "", children: elements)
    }
}

func parseInlineMarkdown(_ text: String) -> [MarkdownElement] {
    var elements: [MarkdownElement] = []
    let currentText = text
    
    // Parse links first [text](url)
    let linkPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
    let linkRegex = try! NSRegularExpression(pattern: linkPattern)
    let linkMatches = linkRegex.matches(in: currentText, range: NSRange(currentText.startIndex..., in: currentText))
    
    var lastEnd = currentText.startIndex
    
    for match in linkMatches {
        // Add text before the link
        if match.range.location > 0 {
            let beforeRange = lastEnd..<currentText.index(currentText.startIndex, offsetBy: match.range.location)
            let beforeText = String(currentText[beforeRange])
            if !beforeText.isEmpty {
                elements.append(contentsOf: parseSimpleMarkdown(beforeText))
            }
        }
        
        // Add the link
        let linkTextRange = Range(match.range(at: 1), in: currentText)!
        let linkUrlRange = Range(match.range(at: 2), in: currentText)!
        let linkText = String(currentText[linkTextRange])
        let linkUrl = String(currentText[linkUrlRange])
        
        elements.append(MarkdownElement(type: .link, content: linkText, url: linkUrl))
        
        lastEnd = currentText.index(currentText.startIndex, offsetBy: match.range.location + match.range.length)
    }
    
    // Add remaining text
    if lastEnd < currentText.endIndex {
        let remainingText = String(currentText[lastEnd...])
        elements.append(contentsOf: parseSimpleMarkdown(remainingText))
    }
    
    return elements.isEmpty ? parseSimpleMarkdown(text) : elements
}

func parseSimpleMarkdown(_ text: String) -> [MarkdownElement] {
    var elements: [MarkdownElement] = []
    let currentText = text
    
    // Find all markdown patterns and their positions
    var patterns: [(range: Range<String.Index>, type: MarkdownType, content: String)] = []
    
    // Find bold patterns **text**
    let boldRegex = try! NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#)
    let boldMatches = boldRegex.matches(in: currentText, range: NSRange(currentText.startIndex..., in: currentText))
    for match in boldMatches {
        if let range = Range(match.range, in: currentText),
           let contentRange = Range(match.range(at: 1), in: currentText) {
            let content = String(currentText[contentRange])
            patterns.append((range: range, type: .bold, content: content))
        }
    }
    
    // Find italic patterns *text* (but not **text**)
    let italicRegex = try! NSRegularExpression(pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#)
    let italicMatches = italicRegex.matches(in: currentText, range: NSRange(currentText.startIndex..., in: currentText))
    for match in italicMatches {
        if let range = Range(match.range, in: currentText),
           let contentRange = Range(match.range(at: 1), in: currentText) {
            let content = String(currentText[contentRange])
            patterns.append((range: range, type: .italic, content: content))
        }
    }
    
    // Find underline patterns _text_
    let underlineRegex = try! NSRegularExpression(pattern: #"_([^_]+)_"#)
    let underlineMatches = underlineRegex.matches(in: currentText, range: NSRange(currentText.startIndex..., in: currentText))
    for match in underlineMatches {
        if let range = Range(match.range, in: currentText),
           let contentRange = Range(match.range(at: 1), in: currentText) {
            let content = String(currentText[contentRange])
            patterns.append((range: range, type: .underline, content: content))
        }
    }
    
    // Find code patterns `text`
    let codeRegex = try! NSRegularExpression(pattern: #"`([^`]+)`"#)
    let codeMatches = codeRegex.matches(in: currentText, range: NSRange(currentText.startIndex..., in: currentText))
    for match in codeMatches {
        if let range = Range(match.range, in: currentText),
           let contentRange = Range(match.range(at: 1), in: currentText) {
            let content = String(currentText[contentRange])
            patterns.append((range: range, type: .code, content: content))
        }
    }
    
    // Find strikethrough patterns ~text~
    let strikethroughRegex = try! NSRegularExpression(pattern: #"~([^~]+)~"#)
    let strikethroughMatches = strikethroughRegex.matches(in: currentText, range: NSRange(currentText.startIndex..., in: currentText))
    for match in strikethroughMatches {
        if let range = Range(match.range, in: currentText),
           let contentRange = Range(match.range(at: 1), in: currentText) {
            let content = String(currentText[contentRange])
            patterns.append((range: range, type: .strikethrough, content: content))
        }
    }
    
    // Sort patterns by their start position
    patterns.sort { $0.range.lowerBound < $1.range.lowerBound }
    
    // Remove overlapping patterns (keep the first one found)
    var filteredPatterns: [(range: Range<String.Index>, type: MarkdownType, content: String)] = []
    for pattern in patterns {
        let overlaps = filteredPatterns.contains { existing in
            pattern.range.overlaps(existing.range)
        }
        if !overlaps {
            filteredPatterns.append(pattern)
        }
    }
    
    // Build elements from the filtered patterns
    var lastEnd = currentText.startIndex
    
    for pattern in filteredPatterns {
        // Add text before this pattern
        if pattern.range.lowerBound > lastEnd {
            let beforeText = String(currentText[lastEnd..<pattern.range.lowerBound])
            if !beforeText.isEmpty {
                elements.append(MarkdownElement(type: .text, content: beforeText))
            }
        }
        
        // Add the formatted element
        elements.append(MarkdownElement(type: pattern.type, content: pattern.content))
        
        lastEnd = pattern.range.upperBound
    }
    
    // Add any remaining text
    if lastEnd < currentText.endIndex {
        let remainingText = String(currentText[lastEnd...])
        if !remainingText.isEmpty {
            elements.append(MarkdownElement(type: .text, content: remainingText))
        }
    }
    
    // If no patterns were found, return the original text
    if elements.isEmpty && !currentText.isEmpty {
        elements.append(MarkdownElement(type: .text, content: currentText))
    }
    
    return elements
}

// Then update the ThoughtDetailView to use this callback
struct ThoughtDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @ObservedObject var tagManager: TagManager
    @Binding var thought: Thought?
    @Binding var selectedFilterTags: [Tag]
    @State private var content: String = ""
    @State private var selectedTags: [Tag] = []
    @State private var showTagSelection = false
    @State private var showingToast = false
    @State private var showExportSheet = false
    @State private var hasChanges: Bool = false
    @State private var showingDatePicker = false
    @State private var selectedDate: Date
    @State private var showingImagePicker = false
    @State private var showingVoiceRecorder = false
    @State private var images: [UIImage] = []
    @State private var imagesWereModified: Bool = false // Track if images were actually changed
    @State private var showingDateInfo = false
    @State private var selectedImageForViewing: UIImage?
    @State private var lastContentUpdate: Date?
    @State private var isFavorite: Bool = false
    @State private var hasInitialThought: Bool = false
    @State private var recordings: [VoiceRecording] = []
    @AppStorage("showAllTags") private var showAllTags = false
    let onSave: () -> Void

    @FocusState private var focusedField: Field?

    @State private var loadedImages: [UIImage] = []
    
    @State private var originalImagePositions: [CGPoint] = []
    @State private var imagePositions: [CGPoint] = []
    @State private var imageScales: [CGFloat] = []
    
    @State private var showingMediaGallery = false
    @State private var showingImageGallery = false
    @State private var showingRecordingsGallery = false
    @State private var navigateToImageGallery = false
    @State private var navigateToRecordingsGallery = false
    
    @State private var isSaving: Bool = false // Add flag to prevent concurrent saves
    @State private var isEditMode: Bool = true // Track edit/read mode
    @State private var showingMarkdownHelp = false // Track markdown help popup
    @State private var keyboardHeight: CGFloat = 0

    private var hasMedia: Bool {
        hasImages || hasRecordings
    }
    
    private var hasImages: Bool {
        return imageCount > 0
    }
    
    private var imageCount: Int {
        guard let thought = thought, let imageData = thought.images else { return 0 }
        
        // Try the data array method first (matches the saving format)
        do {
            if let imageDataArray = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSData.self], from: imageData) as? [Data] {
                return imageDataArray.count
            }
        } catch {
            // Don't print errors here since this is called frequently for display
        }
        
        // Try the secure NSKeyedUnarchiver method
        if let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: imageData) {
            unarchiver.requiresSecureCoding = true
            
            if let imageDataArray = unarchiver.decodeObject(of: [NSArray.self, NSData.self], forKey: "images") as? [Data] {
                return imageDataArray.count
            }
        }
        
        // Fall back to legacy UIImage array method
        if let savedImages = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: imageData) as? [UIImage] {
            return savedImages.count
        }
        
        // Try the combined data format as last resort
        if let images = parseImageData(imageData) {
            return images.count
        }
        
        return 0
    }
    
    private var hasRecordings: Bool {
        guard let thought = thought else { return false }
        let request = VoiceRecording.fetchRequest()
        request.predicate = NSPredicate(format: "thought == %@", thought)
        request.fetchLimit = 1
        
        do {
            let count = try viewContext.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }
    
    private var recordingCount: Int {
        guard let thought = thought else { return 0 }
        let request = VoiceRecording.fetchRequest()
        request.predicate = NSPredicate(format: "thought == %@", thought)
        
        do {
            let count = try viewContext.count(for: request)
            return count
        } catch {
            return 0
        }
    }

    init(thought: Binding<Thought?>, tagManager: TagManager, selectedFilterTags: Binding<[Tag]>, onSave: @escaping () -> Void) {
        self._thought = thought
        self.tagManager = tagManager
        self._selectedFilterTags = selectedFilterTags
        self.onSave = onSave
        self._selectedDate = State(initialValue: thought.wrappedValue?.creationDate ?? Date())
        self._isFavorite = State(initialValue: thought.wrappedValue?.favorite ?? false)
        
        // Initialize images array from thought data
        var initialImages: [UIImage] = []
        if let thought = thought.wrappedValue,
           let imageData = thought.images {
            // Try the new combined data format first
            if let loadedImages = parseImageData(imageData) {
                initialImages = loadedImages
                print("✅ Successfully loaded \(initialImages.count) images using new combined format")
            } else {
                // Try the newer method of loading images from Data array first
                if let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: imageData) {
                    unarchiver.requiresSecureCoding = true
                    
                    if let imageDataArray = unarchiver.decodeObject(of: [NSArray.self, NSData.self], forKey: "images") as? [Data] {
                        let savedImages = imageDataArray.compactMap { UIImage(data: $0) }
                        if !savedImages.isEmpty {
                            initialImages = savedImages
                            print("✅ Successfully loaded \(savedImages.count) images using secure data array method")
                        }
                    }
                }
                
                // Try the alternative data array method if first method failed
                if initialImages.isEmpty {
                    do {
                        if let imageDataArray = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSData.self], from: imageData) as? [Data] {
                            let savedImages = imageDataArray.compactMap { UIImage(data: $0) }
                            if !savedImages.isEmpty {
                                initialImages = savedImages
                                print("✅ Successfully loaded \(savedImages.count) images using alternative data array method")
                            }
                        }
                    } catch {
                        print("Failed to load images using alternative data array method: \(error)")
                    }
                }
                
                // Fall back to legacy method if both data array methods failed
                if initialImages.isEmpty {
                    if let savedImages = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: imageData) as? [UIImage], !savedImages.isEmpty {
                        initialImages = savedImages
                        print("✅ Successfully loaded \(savedImages.count) images using legacy UIImage method")
                    } else {
                        print("Failed to load images using legacy UIImage method")
                    }
                }
            }
            
            if !initialImages.isEmpty {
                let screenWidth = UIScreen.main.bounds.width
                let centerY = 150.0
                
                for _ in 0..<initialImages.count {
                    let position = CGPoint(x: screenWidth/2, y: centerY)
                    imagePositions.append(position)
                    originalImagePositions.append(position)
                    imageScales.append(1.0)
                }
                
                print("Initialized positions for \(initialImages.count) loaded images")
            }
        }
        self._images = State(initialValue: initialImages)
    }
    
    enum Field: Int, CaseIterable {
        case content
    }

    private func updateCreationDate(_ newDate: Date) {
        selectedDate = newDate
        hasChanges = true
        
        // If we have an existing thought, update its creation date immediately
        if let existingThought = thought {
            existingThought.creationDate = newDate
            saveContext(forceSave: true)
            print("Creation date updated for thought: \(newDate)")
        }
    }

    private func toggleFavorite() {
        isFavorite.toggle()
        hasChanges = true
        
        // If we have an existing thought, update its favorite status immediately
        if let existingThought = thought {
            existingThought.favorite = isFavorite
            saveContext(forceSave: true)
            print("Favorite status updated for thought: \(isFavorite)")
            
            // Trigger the onSave callback to refresh the parent view
            onSave()
        }
    }

    private func saveContext(forceSave: Bool = false) {
        do {
            if forceSave || viewContext.hasChanges {
                try viewContext.save()
                print("✅ Context saved successfully")
                
                // Don't refresh with mergeChanges: false as it might cause issues
                // Instead, just verify the save was successful
                if let currentThought = thought {
                    print("🔍 Verification: Thought still exists with ID: \(currentThought.objectID.description)")
                    print("🔍 Thought content length: \(currentThought.content?.count ?? 0)")
                } else {
                    print("⚠️ Warning: Thought became nil after save!")
                }
                
                hasChanges = false
                
                // Additional verification: check if images were actually saved
                if let currentThought = thought, let savedImageData = currentThought.images {
                    print("✅ Verification: Thought now has \(savedImageData.count) bytes of image data")
                } else if thought != nil {
                    print("⚠️ Verification: Thought has no image data after save")
                }
                
                // Reset modification flags after successful save
                imagesWereModified = false
                
                // Trigger the onSave callback to refresh the parent view
                onSave()
            }
        } catch {
            print("❌ Failed to save context: \(error)")
            
            // Don't rollback when offline - preserve the state
            if !isOffline() {
                viewContext.rollback()
            }
        }
    }

    private func saveThought() {
        // Prevent concurrent saves that could cause duplicate thoughts
        if isSaving {
            print("🚫 Save already in progress, skipping this save request")
            return
        }
        
        isSaving = true
        defer { isSaving = false } // Always reset the flag when function exits
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent = !trimmedContent.isEmpty
        let hasImages = !images.isEmpty
        let hasAnyContent = hasContent || hasImages
        
        print("🔄 saveThought() called - content length: \(content.count), trimmed: \(trimmedContent.count), hasImages: \(hasImages), hasChanges: \(hasChanges)")
        print("🔍 Current thought state: \(thought?.objectID.description ?? "nil"), hasInitialThought: \(hasInitialThought)")
        print("🔍 Detailed state - thought exists: \(thought != nil), hasAnyContent: \(hasAnyContent), offline: \(isOffline())")
        
        // Check if we're offline
        if isOffline() {
            print("Device is offline - preserving current state")
            return
        }
        
        let currentDate = Date()
        
        // Process images
        let processedImages = images.compactMap { image -> UIImage? in
            let maxDimension: CGFloat = 1024
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
            
            if scale < 1.0 {
                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                return scaledImage
            }
            return image
        }
        
        // Archive images - using proper secure coding method
        let imageData: Data?
        if !processedImages.isEmpty {
            // Convert UIImages to Data first
            let imageDataArray = processedImages.compactMap { image -> Data? in
                return image.jpegData(compressionQuality: 0.7)
            }
            
            if !imageDataArray.isEmpty {
                let archiver = NSKeyedArchiver(requiringSecureCoding: true)
                archiver.encode(imageDataArray as NSArray, forKey: "images")
                imageData = archiver.encodedData
                
                print("✅ Successfully archived \(imageDataArray.count) images using NSKeyedArchiver: \(imageData?.count ?? 0) bytes")
            } else {
                print("❌ Failed to convert images to JPEG data")
                imageData = nil
            }
        } else {
            imageData = nil
            print("No images to archive")
        }
        
        // Prepare tags string
        let tagsString = selectedTags.map { $0.name }.joined(separator: ",")
        
        // Update existing thought
        if let existingThought = thought {
            print("📝 Updating existing thought with content: '\(trimmedContent.prefix(50))'")
            print("🔍 Existing thought ID: \(existingThought.objectID.description)")
            // Only delete if there's no content AND no images AND we're not offline
            if !hasAnyContent && !isOffline() {
                viewContext.delete(existingThought)
                thought = nil
                hasInitialThought = false
                print("🗑️ Deleted empty thought (no content or images)")
            } else {
                // Update thought properties
                existingThought.content = trimmedContent
                existingThought.tag = selectedTags.first?.name // For backward compatibility
                existingThought.tags = tagsString
                existingThought.lastUpdated = currentDate
                
                // Always update images if we have any images or if they were modified
                if !images.isEmpty || imagesWereModified {
                    existingThought.images = imageData
                    print("🔄 Updated images in Core Data - \(processedImages.count) images")
                    
                    // For improved debugging
                    if imageData != nil {
                        print("✅ Saved \(processedImages.count) images (\(imageData!.count) bytes) to existing thought")
                        print("Thought now has images data: \(existingThought.images?.count ?? 0) bytes")
                    } else {
                        print("No images to save for existing thought")
                    }
                } else {
                    print("⏭️ No images to update")
                    print("Existing thought retains: \(existingThought.images?.count ?? 0) bytes of image data")
                }
                
                existingThought.favorite = isFavorite
                existingThought.creationDate = selectedDate
                print("✅ Updated existing thought successfully")
            }
        }
        // Create new thought - simplified condition to avoid issues
        else if hasAnyContent && !isOffline() {
            print("🆕 Creating new thought with content: '\(trimmedContent.prefix(50))'")
            print("🔍 About to create new thought - current thought is nil: \(thought == nil)")
            
            let newThought = Thought(context: viewContext)
            newThought.content = trimmedContent
            newThought.tag = selectedTags.first?.name // For backward compatibility
            newThought.tags = tagsString
            newThought.lastUpdated = currentDate
            newThought.creationDate = selectedDate
            newThought.images = imageData
            newThought.favorite = isFavorite
            
            print("🔍 Created new thought object with ID: \(newThought.objectID.description)")
            
            // Set the thought binding and mark as initialized
            thought = newThought
            hasInitialThought = true
            
            print("🔍 After setting binding - thought is now: \(thought?.objectID.description ?? "still nil")")
            print("🔍 hasInitialThought is now: \(hasInitialThought)")
            
            if imageData != nil {
                print("✅ Created new thought with \(processedImages.count) images (\(imageData!.count) bytes) and content: '\(trimmedContent.prefix(50))'")
                print("New thought has images data: \(newThought.images?.count ?? 0) bytes")
            } else {
                print("✅ Created new thought with content: '\(trimmedContent.prefix(50))'")
            }
        }
        // If we have a thought but no content/images, we still need to save any metadata changes
        else if thought != nil && !isOffline() {
            print("💾 Saving metadata changes for existing thought (no content/image changes)")
        }
        else {
            print("⚠️ No save action taken - hasAnyContent: \(hasAnyContent), thought: \(thought?.objectID.description ?? "nil"), hasInitialThought: \(hasInitialThought), offline: \(isOffline())")
            print("🔍 Detailed analysis:")
            print("   - hasContent: \(hasContent)")
            print("   - hasImages: \(hasImages)")
            print("   - hasAnyContent: \(hasAnyContent)")
            print("   - thought == nil: \(thought == nil)")
            print("   - isOffline(): \(isOffline())")
        }
        
        // Try to save context if we have changes and we're not offline
                        if !isOffline() {
            print("🔍 About to save context - thought before save: \(thought?.objectID.description ?? "nil")")
            saveContext(forceSave: true)
            print("🔍 After saving context - thought after save: \(thought?.objectID.description ?? "nil")")
        } else {
            print("Device is offline - preserving current state without saving")
        }
    }
    
    private func cleanup() {
        // Clear UI-related objects when view disappears, but preserve data needed for saving
        imagePositions = []
        originalImagePositions = []
        imageScales = []
        selectedImageForViewing = nil
        loadedImages = []
        
        // Don't clear images or content here as they may need to be saved
    }
    
    private var imageViewerBinding: Binding<Bool> {
        Binding<Bool>(
            get: { selectedImageForViewing != nil },
            set: { if !$0 { selectedImageForViewing = nil } }
        )
    }

    private func loadRecordings() {
        guard let thought = thought else { return }
        let request = VoiceRecording.fetchRequest()
        request.predicate = NSPredicate(format: "thought == %@", thought)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \VoiceRecording.createdAt, ascending: false)]
        
        do {
            recordings = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch recordings: \(error)")
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                // Tag and media section
                HStack {
                    // Tag button (left justified)
                    HStack(spacing: 6) {
                    Button(action: { showTagSelection = true }) {
                            Image("tag")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(Color.colorPrimary)
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.colorPrimary.opacity(0.1))
                                .cornerRadius(30)
                        }
                        
                        DetailTagDisplayView(selectedTags: selectedTags)
                    }
                    
                    Spacer()
                    
                    // Media indicator buttons (right justified)
                    mediaIndicators
                }
                .padding(.horizontal)
                .frame(minHeight: 40)
                
                // Text editor
                if isEditMode {
                    TextEditor(text: $content)
                        .focused($focusedField, equals: .content)
                    .padding()
                        .onTapGesture(count: 2) {
                            // Double tap to switch to read mode
                            isEditMode = false
                        }
                } else {
                    // Read mode with markdown rendering
                    ScrollView {
                        MarkdownRenderer(text: content)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(UIColor.systemBackground))
                    .onTapGesture(count: 2) {
                        // Double tap to switch to edit mode
                        isEditMode = true
                        focusedField = .content
                    }
                }
                
                Spacer()
            }
        }
        // Navigation and toolbar settings
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack {
                    Button(action: {
                        print("🔙 Back button tapped - dismissing view")
                        dismiss()
                    }) {
                        Image("arrow-left")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                            
                    }
                }
            }
            
            // Add menu to the top navigation
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Menu {
                        dateSection
                        photosSection
                        exportSection
                        bookmarkSection
                    } label: {
                        Image("dots-horizontal")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            
                    }
                }
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                if isEditMode {
                    GeometryReader { proxy in
                        let safeBottom = proxy.safeAreaInsets.bottom
                        HStack {
                            markdownFormattingButtons
                            Spacer()
                            Button("Done") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            .foregroundColor(Color.colorPrimary)
                        }
                        .frame(height: 44)
                        .padding(.horizontal)
                        .padding(.bottom, max(0, keyboardHeight - safeBottom))
                    }
                    .frame(height: 44)
                }
            }
        }
        // Change handlers
        .onChange(of: content) { oldValue, newValue in
            // Just mark that we have changes, don't auto-save
                lastContentUpdate = Date()
                hasChanges = true
                
            print("📝 Content changed - marking hasChanges = true")
        }
        .onChange(of: images) { oldValue, newValue in
            lastContentUpdate = Date()
            hasChanges = true
            imagesWereModified = true // Mark that images were actually modified
            
            print("📷 Images changed from \(oldValue.count) to \(newValue.count) - marking as modified")
            
            // Only save immediately if images were added to prevent loss
            // But don't auto-save on every change
            if !newValue.isEmpty && oldValue.isEmpty {
                print("First images added - saving immediately to prevent loss")
                saveThought()
            }
        }
        .onChange(of: selectedTags) { oldValue, newValue in
            hasChanges = true
        }
        // Lifecycle events
        .onAppear {
            // Check for offline backup first (for new thoughts only)
            if thought == nil && loadFromLocalStorage() {
                hasChanges = true
                print("📱 Restored offline backup on app launch")
            }
            
            // Load initial data from thought
            loadInitialData(newThought: thought)
            
            // Load voice recordings
            loadRecordings()
            
            startObservingKeyboard()
        }
        .onDisappear {
            // Save once when the user leaves the view
            print("🔚 View disappearing - saving thought")
                saveThought()
            
            // Also save to local storage as backup
            saveToLocalStorage()
            
            cleanup()
            
            print("✅ Single save on disappear completed - content length: \(content.count)")
            
            // Always trigger refresh when leaving the view to ensure list is up-to-date
            onSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Check connection state when app becomes active
            handleConnectionStateChange()
        }
        // Sheets and modals
        .sheet(isPresented: $showTagSelection) {
            NavigationStack {
                TagSelectionView(
                    tagManager: tagManager,
                    defaultTags: Tag.defaultTags,
                    isPresented: $showTagSelection,
                    selectedTags: $selectedTags,
                    hideBackButton: true
                )
                .toolbar {
                    // Replace the back button with a done button
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showTagSelection = false
                        }) {
                            Image("arrow-down")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color.colorPrimary)
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExportSheet) {
            NavigationStack {
                ExportOptionsView(thought: thought)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                DatePickerView(
                    selectedDate: $selectedDate,
                    onDismiss: { showingDatePicker = false },
                    onSave: { newDate in
                        updateCreationDate(newDate)
                        showingDatePicker = false
                    }
                )
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: $images)
                .presentationDetents([.medium, .large])
                .onDisappear {
                    // Only update if new images were added
                    if !images.isEmpty {
                        // Create thought if it doesn't exist when images are added
                        if thought == nil {
                            createThoughtIfNeeded()
                        }
                        
                        // Initialize position and scale tracking for the images
                        // This happens on disappear to ensure all picked images are processed
                        let screenWidth = UIScreen.main.bounds.width
                        let centerY = 150.0
                        
                        // Make sure these arrays match the current image count
                        // Start fresh to ensure no mismatch
                        imagePositions = []
                        originalImagePositions = []
                        imageScales = []
                        
                        for _ in 0..<images.count {
                            let position = CGPoint(x: screenWidth/2, y: centerY)
                            imagePositions.append(position)
                            originalImagePositions.append(position)
                            imageScales.append(1.0)
                        }
                        
                        print("Updated positions for \(images.count) images after picker")
                        hasChanges = true
                        imagesWereModified = true // Ensure this flag is set when images are added
                    }
                }
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            NavigationStack {
                VoiceRecorderView(thought: {
                    // Create thought if it doesn't exist when voice recorder opens
                    if thought == nil {
                        createThoughtIfNeeded()
                    }
                    return thought
                }())
                    .environment(\.managedObjectContext, viewContext)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                showingVoiceRecorder = false
                                loadRecordings()
                            }) {
                                Text("Done".localized)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.colorPrimary)
                            }
                        }
                    }
            }
            .onDisappear {
                loadRecordings()
            }
        }
        .sheet(isPresented: $showingMarkdownHelp) {
            NavigationStack {
                MarkdownHelpView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                showingMarkdownHelp = false
                            }) {
                                Text("Done".localized)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.colorPrimary)
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Overlay for toast message
        .overlay(
            Group {
                if showingToast {
                    Text("Copied to Clipboard".localized)
                        .bold()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(6)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.5), value: showingToast)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showingToast = false
                            }
                        }
                }
            }
        )
    }
    
    // Load initial data from the thought
    func loadInitialData(newThought: Thought?) {
        thought = newThought
        
        if let thought = newThought {
            content = thought.content ?? ""
            
            // Start in read mode for existing thoughts with content, edit mode for empty thoughts
            isEditMode = content.isEmpty
            
            // Load tags from the thought
            selectedTags = []
            
            // First try to load from the tags field (comma-separated list)
            if let tagsString = thought.tags, !tagsString.isEmpty {
                let tagNames = tagsString.split(separator: ",").map { String($0) }
                for tagName in tagNames {
                    if let tag = tagManager.getTagByName(tagName) {
                        selectedTags.append(tag)
                    }
                }
            } 
            // Fall back to the single tag field for backward compatibility
            else if let tagName = thought.tag, !tagName.isEmpty {
                if let tag = tagManager.getTagByName(tagName) {
                    selectedTags = [tag]
                }
            }
            
            // Update favorite state from the thought
            isFavorite = thought.favorite
            
            // Update selectedDate from the thought's creation date
            if let creationDate = thought.creationDate {
                selectedDate = creationDate
            }
            
            // Update timestamp when opening an existing thought
            thought.timestamp = Date()
            do {
                try viewContext.save()
                print("Successfully updated timestamp")
            } catch {
                print("Failed to save timestamp: \(error)")
            }
            
            // Clear any existing image data
            images = []
            imagePositions = []
            originalImagePositions = []
            imageScales = []
            
            // Load images from thought data
            if let imageData = thought.images {
                print("Loading images for thought: \(String(describing: thought.content?.prefix(20)))")
                var loadedSuccessfully = false
                
                // Try the data array method first (matches the saving format)
                do {
                    if let imageDataArray = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSData.self], from: imageData) as? [Data] {
                        let savedImages = imageDataArray.compactMap { UIImage(data: $0) }
                        if !savedImages.isEmpty {
                            images = savedImages
                            loadedSuccessfully = true
                            print("✅ Successfully loaded \(savedImages.count) images using data array method")
                        }
                    }
                } catch {
                    print("Failed to load images using data array method: \(error)")
                }
                
                // Try the secure NSKeyedUnarchiver method if first method failed
                if !loadedSuccessfully {
                    if let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: imageData) {
                        unarchiver.requiresSecureCoding = true
                        
                        if let imageDataArray = unarchiver.decodeObject(of: [NSArray.self, NSData.self], forKey: "images") as? [Data] {
                            let savedImages = imageDataArray.compactMap { UIImage(data: $0) }
                            if !savedImages.isEmpty {
                                images = savedImages
                                loadedSuccessfully = true
                                print("✅ Successfully loaded \(savedImages.count) images using secure NSKeyedArchiver method")
                            }
                        }
                    }
                }
                
                // Fall back to legacy UIImage array method if data array methods failed
                if !loadedSuccessfully {
                    if let savedImages = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: imageData) as? [UIImage], !savedImages.isEmpty {
                        images = savedImages
                        loadedSuccessfully = true
                        print("✅ Successfully loaded \(savedImages.count) images using legacy UIImage method")
                    } else {
                        print("Failed to load images using legacy UIImage method")
                    }
                }
                
                // Try the combined data format as last resort
                if !loadedSuccessfully {
                    if let loadedImages = parseImageData(imageData) {
                        images = loadedImages
                        loadedSuccessfully = true
                        print("✅ Successfully loaded \(loadedImages.count) images using combined format")
                    }
                }
                
                if !loadedSuccessfully {
                    print("❌ All image loading methods failed for thought with \(imageData.count) bytes of image data")
                } else {
                    print("✅ Successfully loaded \(images.count) images")
                }
                
                // Initialize positions and scales for loaded images
                if !images.isEmpty {
                    let screenWidth = UIScreen.main.bounds.width
                    let centerY = 150.0
                    
                    for _ in 0..<images.count {
                        let position = CGPoint(x: screenWidth/2, y: centerY)
                        imagePositions.append(position)
                        originalImagePositions.append(position)
                        imageScales.append(1.0)
                    }
                    
                    print("Initialized positions for \(images.count) loaded images")
                }
            } else {
                print("No image data found for thought")
            }
        } else {
            content = ""
            selectedTags = []
            images = []
            imagePositions = []
            originalImagePositions = []
            imageScales = []
            // Reset favorite state for new thoughts
            isFavorite = false
            // For new thoughts, initialize selectedDate to current date
            selectedDate = Date()
            // Start in edit mode for new thoughts
            isEditMode = true
        }
        hasChanges = false
        imagesWereModified = false // Reset the images modified flag
    }
    
    private func copyContentToClipboard() {
        UIPasteboard.general.string = content
        showingToast = true
    }
    
    private func resetImagePositions() {
        // Reset all images to their original positions and scales
        for i in 0..<imagePositions.count {
            withAnimation(.spring()) {
                imagePositions[i] = originalImagePositions[i]
                imageScales[i] = 1.0
            }
        }
    }

    var imageSection: some View {
        VStack {
            if !images.isEmpty {
                ZStack {
                    ForEach(0..<images.count, id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .position(imagePositions[index])
                            .scaleEffect(imageScales[index])
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        // Use more efficient updates to reduce lag
                                        imagePositions[index] = CGPoint(
                                            x: originalImagePositions[index].x + value.translation.width,
                                            y: originalImagePositions[index].y + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        // Update original position when drag ends
                                        originalImagePositions[index] = imagePositions[index]
                                    }
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        imageScales[index] = value
                                    }
                                    .onEnded { value in
                                        imageScales[index] = value
                                    }
                            )
                            // Use drawingGroup for better performance with complex views
                            .drawingGroup()
                    }
                }
                .frame(height: 300)
                
                HStack {
                    Button(action: {
                        resetImagePositions()
                    }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .foregroundColor(Color.colorPrimary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Remove all images
                        images = []
                        imagePositions = []
                        originalImagePositions = []
                        imageScales = []
                    }) {
                        Label("Clear All", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // Improve the offline detection method
    private func isOffline() -> Bool {
        // Check if we can access the persistent store coordinator and if it has any stores
        guard let coordinator = viewContext.persistentStoreCoordinator else {
            return true
        }
        
        // Check if we have any persistent stores
        if coordinator.persistentStores.isEmpty {
            return true
        }
        
        // Try to perform a simple fetch to verify store access
        let fetchRequest: NSFetchRequest<Thought> = Thought.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            _ = try viewContext.count(for: fetchRequest)
            return false
        } catch {
            print("Failed to access store: \(error)")
            return true
        }
    }

    // Add method to handle connection state changes
    private func handleConnectionStateChange() {
        if !isOffline() {
            // We're back online, try to restore and sync any offline changes
            if UserDefaults.standard.object(forKey: "offlineThoughtBackup") != nil {
                print("📶 Back online - syncing offline changes")
                
                // Try to save any pending changes first
            if hasChanges {
                saveThought()
            }
                
                // If save was successful, clear the offline backup
                if !hasChanges {
                    clearLocalStorage()
                }
            } else if hasChanges {
                // No offline backup but we have changes, save them
                saveThought()
            }
        }
    }

    // MARK: - Keyboard handling
    private func startObservingKeyboard() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { notification in
            guard let userInfo = notification.userInfo,
                  let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
            let screenHeight = UIScreen.main.bounds.height
            let keyboardEndY = endFrame.origin.y
            let height = max(0, screenHeight - keyboardEndY)
            self.keyboardHeight = height
        }
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            self.keyboardHeight = 0
        }
    }

    private func insertMarkdown(_ syntax: String) {
        // Simply insert the markdown syntax at the current cursor position
        // Users can type their text and tap the button again to close the formatting
        // Always insert inline, never go to a new line
        
        if content.isEmpty {
            content = syntax
        } else {
            // Always add to the end inline, no new lines
            content += syntax
        }
        hasChanges = true
    }
    
    private func insertLink() {
        let linkMarkdown = "[Link Text](https://example.com)"
        if content.isEmpty {
            content = linkMarkdown
        } else {
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content == trimmedContent {
                content += " " + linkMarkdown
            } else {
                content += "\n" + linkMarkdown
            }
        }
        hasChanges = true
    }

    // Parse images from the new combined data format
    private func parseImageData(_ data: Data) -> [UIImage]? {
        guard data.count > 4 else {
            print("Image data too small for new format")
            return nil
        }
        
        var offset = 0
        var images: [UIImage] = []
        
        // Read metadata size
        let metadataSize = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        offset += 4
        
        guard offset + Int(metadataSize) <= data.count else {
            print("Invalid metadata size in image data")
            return nil
        }
        
        // Read and parse metadata (optional - we don't strictly need it for loading)
        let metadataData = data.subdata(in: offset..<offset+Int(metadataSize))
        offset += Int(metadataSize)
        
        if let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any] {
            print("Found metadata for \(metadata.count) images")
        }
        
        // Read individual images
        while offset < data.count {
            // Read image size
            guard offset + 4 <= data.count else { break }
            let imageSize = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            offset += 4
            
            // Read image data
            guard offset + Int(imageSize) <= data.count else {
                print("Invalid image size in combined data")
                break
            }
            
            let imageData = data.subdata(in: offset..<offset+Int(imageSize))
            offset += Int(imageSize)
            
            // Create UIImage
            if let image = UIImage(data: imageData) {
                images.append(image)
                print("✅ Parsed image: \(imageSize) bytes")
            } else {
                print("❌ Failed to create UIImage from data")
            }
        }
        
        return images.isEmpty ? nil : images
    }

    // Local storage for offline persistence
    private func saveToLocalStorage() {
        let defaults = UserDefaults.standard
        let thoughtData: [String: Any] = [
            "content": content,
            "selectedTags": selectedTags.map { $0.name },
            "isFavorite": isFavorite,
            "selectedDate": selectedDate.timeIntervalSince1970,
            "lastSaved": Date().timeIntervalSince1970,
            "thoughtID": thought?.objectID.uriRepresentation().absoluteString ?? "new"
        ]
        
        // Save current thought to UserDefaults as backup
        defaults.set(thoughtData, forKey: "offlineThoughtBackup")
        
        // Also save images to local cache if any exist
        if !images.isEmpty {
            saveImagesToLocalCache()
        }
        
        print("💾 Saved thought to local storage (offline backup)")
    }
    
    private func saveImagesToLocalCache() {
        guard !images.isEmpty else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = documentsPath.appendingPathComponent("offline_cache")
        
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            
            for (index, image) in images.enumerated() {
                if let imageData = image.jpegData(compressionQuality: 0.7) {
                    let imagePath = cacheDirectory.appendingPathComponent("image_\(index).jpg")
                    try imageData.write(to: imagePath)
                }
            }
            
            // Save image count to UserDefaults
            UserDefaults.standard.set(images.count, forKey: "offlineImageCount")
            print("💾 Saved \(images.count) images to local cache")
            
        } catch {
            print("❌ Failed to save images to local cache: \(error)")
        }
    }
    
    private func loadFromLocalStorage() -> Bool {
        let defaults = UserDefaults.standard
        guard let thoughtData = defaults.object(forKey: "offlineThoughtBackup") as? [String: Any] else {
            return false
        }
        
        // Restore content and settings
        content = thoughtData["content"] as? String ?? ""
        isFavorite = thoughtData["isFavorite"] as? Bool ?? false
        
        if let timestamp = thoughtData["selectedDate"] as? TimeInterval {
            selectedDate = Date(timeIntervalSince1970: timestamp)
        }
        
        // Restore tags
        if let tagNames = thoughtData["selectedTags"] as? [String] {
            selectedTags = tagNames.compactMap { tagManager.getTagByName($0) }
        }
        
        // Load cached images
        loadImagesFromLocalCache()
        
        print("📱 Restored thought from local storage")
        return true
    }
    
    private func loadImagesFromLocalCache() {
        let imageCount = UserDefaults.standard.integer(forKey: "offlineImageCount")
        guard imageCount > 0 else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = documentsPath.appendingPathComponent("offline_cache")
        
        var loadedImages: [UIImage] = []
        
        for index in 0..<imageCount {
            let imagePath = cacheDirectory.appendingPathComponent("image_\(index).jpg")
            if let imageData = try? Data(contentsOf: imagePath),
               let image = UIImage(data: imageData) {
                loadedImages.append(image)
            }
        }
        
        if !loadedImages.isEmpty {
            images = loadedImages
            print("📱 Restored \(loadedImages.count) images from local cache")
        }
    }
    
    private func clearLocalStorage() {
        UserDefaults.standard.removeObject(forKey: "offlineThoughtBackup")
        UserDefaults.standard.removeObject(forKey: "offlineImageCount")
        
        // Clear image cache
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = documentsPath.appendingPathComponent("offline_cache")
        
        try? FileManager.default.removeItem(at: cacheDirectory)
        print("🧹 Cleared local storage backup")
    }
    
    // Helper function to create a temporary thought when needed for media
    private func createTemporaryThought() -> Thought {
        if let existingThought = thought {
            return existingThought
        }
        
        let newThought = Thought(context: viewContext)
        newThought.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        newThought.creationDate = selectedDate
        newThought.lastUpdated = Date()
        newThought.favorite = isFavorite
        
        // Set tags
        let tagsString = selectedTags.map { $0.name }.joined(separator: ",")
        newThought.tags = tagsString
        newThought.tag = selectedTags.first?.name
        
        thought = newThought
        hasInitialThought = true
        
        // Save immediately to ensure the thought exists for media
        saveContext(forceSave: true)
        
        print("🆕 Created temporary thought for media attachment")
        return newThought
    }
    
    // Helper function to create thought if needed
    private func createThoughtIfNeeded() {
        if thought == nil {
            _ = createTemporaryThought()
        }
    }

    // Extract menu sections into computed properties to avoid compiler issues
    @ViewBuilder
    private var dateSection: some View {
        Section {
            Button(action: { showingDatePicker = true }) {
                Label {
                    Text("Created: \(selectedDate.formatted(date: .abbreviated, time: .omitted))".localized)
                        .font(.caption)
                } icon: {
                    Image(systemName: "calendar")
                }
            }
            
            Label {
                Text("Updated: \(thought?.lastUpdated?.formatted(date: .abbreviated, time: .omitted) ?? Date().formatted(date: .abbreviated, time: .omitted))".localized)
                    .font(.caption)
            } icon: {
                Image(systemName: "clock")
            }
        }
    }
    
    @ViewBuilder
    private var photosSection: some View {
        Section {
            Button(action: { 
                // Create thought if needed for images
                if thought == nil {
                    createThoughtIfNeeded()
                }
                showingImagePicker = true 
            }) {
                Label("Add Photos", systemImage: "photo")
            }
            
            Button(action: { 
                // Create thought if needed for voice recording
                if thought == nil {
                    createThoughtIfNeeded()
                }
                showingVoiceRecorder = true 
            }) {
                Label("Record Voice", systemImage: "mic")
            }
            
            if hasImages {
                NavigationLink(destination: {
                    if let thought = thought {
                        ImageGalleryView(thought: thought)
                            .environment(\.managedObjectContext, viewContext)
                            .id(thought.objectID)
                    }
                }) {
                    Label("View Photos", systemImage: "photo.on.rectangle")
                }
            }
            
            if hasRecordings {
                NavigationLink(destination: {
                    if let thought = thought {
                        RecordingsGalleryView(thought: thought)
                            .environment(\.managedObjectContext, viewContext)
                            .id(thought.objectID)
                    }
                }) {
                    Label("View Recordings", systemImage: "waveform")
                }
            }
        }
    }
    
    @ViewBuilder
    private var exportSection: some View {
        Section {
            Button(action: copyContentToClipboard) {
                Label("Copy to Clipboard", systemImage: "doc.on.doc")
            }
            
            Button(action: { showExportSheet = true }) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
    }
    
    @ViewBuilder
    private var bookmarkSection: some View {
        Section {
            Button(action: toggleFavorite) {
                Label(isFavorite ? "Remove Bookmark" : "Add Bookmark", 
                      systemImage: isFavorite ? "bookmark.fill" : "bookmark")
            }
        }
    }

    @ViewBuilder
    private var markdownFormattingButtons: some View {
        HStack(spacing: 4) {
            // Markdown help button
            Button(action: { showingMarkdownHelp = true }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(Color.colorPrimary)
                    .frame(minWidth: 22, minHeight: 22)
                    .cornerRadius(6)
            }
            
            Button(action: { insertMarkdown("**") }) {
                Text("B".localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.colorPrimary)
                    .frame(minWidth: 22, minHeight: 22)
                    .cornerRadius(6)
            }
            
            Button(action: { insertMarkdown("*") }) {
                Text("I".localized)
                    .font(.system(size: 16, weight: .regular))
                    .italic()
                    .foregroundColor(Color.colorPrimary)
                    .frame(minWidth: 22, minHeight: 22)
                    .cornerRadius(6)
            }
            
            Button(action: { insertMarkdown("_") }) {
                Text("U".localized)
                    .font(.system(size: 16, weight: .regular))
                    .underline()
                    .foregroundColor(Color.colorPrimary)
                    .frame(minWidth: 22, minHeight: 22)
                    .cornerRadius(6)
            }
            
            Button(action: { insertMarkdown("`") }) {
                Text("C".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.colorPrimary)
                    .frame(minWidth: 22, minHeight: 22)
                    .cornerRadius(6)
            }
            
            Button(action: { insertMarkdown("~") }) {
                Text("S".localized)
                    .font(.system(size: 16, weight: .regular))
                    .strikethrough()
                    .foregroundColor(Color.colorPrimary)
                    .frame(minWidth: 22, minHeight: 22)
                    .cornerRadius(6)
            }
            
            Button(action: { insertLink() }) {
                Image(systemName: "link")
                    .font(.system(size: 12))
                    .foregroundColor(Color.colorPrimary)
                    .frame(minWidth: 22, minHeight: 22)
                    .cornerRadius(6)
            }
        }
    }

    @ViewBuilder
    private var mediaIndicators: some View {
        HStack(spacing: 6) {
            // Images indicator - Button for new thoughts, NavigationLink for existing thoughts
            if let existingThought = thought {
                NavigationLink(destination: {
                    ImageGalleryView(thought: existingThought)
                        .environment(\.managedObjectContext, viewContext)
                        .id(existingThought.objectID)
                }) {
                    HStack(spacing: 4) {
                        Image("image-square")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("\(imageCount)".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.colorPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.colorPrimary.opacity(0.1))
                    .cornerRadius(60)
                }
            } else {
                Button(action: { 
                    // Create thought if needed for images
                    if thought == nil {
                        createThoughtIfNeeded()
                    }
                    showingImagePicker = true 
                }) {
                    HStack(spacing: 4) {
                        Image("image-square")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("\(imageCount)".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.colorPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.colorPrimary.opacity(0.1))
                    .cornerRadius(60)
                }
            }
            
            // Recordings indicator - Button for new thoughts, NavigationLink for existing thoughts
            if let existingThought = thought {
                NavigationLink(destination: {
                    RecordingsGalleryView(thought: existingThought)
                        .environment(\.managedObjectContext, viewContext)
                        .id(existingThought.objectID)
                }) {
                    HStack(spacing: 4) {
                        Image("microphone-alt-1")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("\(recordingCount)".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.colorPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.colorPrimary.opacity(0.1))
                    .cornerRadius(30)
                }
            } else {
                Button(action: { 
                    // Create thought if needed for voice recording
                    if thought == nil {
                        createThoughtIfNeeded()
                    }
                    showingVoiceRecorder = true 
                }) {
                    HStack(spacing: 4) {
                        Image("microphone-alt-1")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("\(recordingCount)".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.colorPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.colorPrimary.opacity(0.1))
                    .cornerRadius(30)
                }
            }
            
            // Edit/Read mode toggle button
            Button(action: { 
                isEditMode.toggle()
                if isEditMode {
                    focusedField = .content
                }
            }) {
                Image(isEditMode ? "file-alt" : "file-pencil-alt")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color.colorPrimary)
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.colorPrimary.opacity(0.1))
                    .cornerRadius(30)
            }
        }
    }
}

// Add this extension near the top of the file or in a separate Modifiers.swift file
extension View {
    func horizontalSlideTransition() -> some View {
        self.transition(.asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        ))
    }
}

// Add DatePickerView implementation
struct DatePickerView: View {
    @Binding var selectedDate: Date
    var onDismiss: () -> Void
    var onSave: (Date) -> Void
    
    var body: some View {
        VStack {
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .padding()
                
                Spacer()
                
                Button("Save") {
                    onSave(selectedDate)
                }
                .padding()
                .fontWeight(.bold)
            }
            
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            
            Spacer()
        }
        .navigationTitle("Choose Date".localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
    }
}

// Markdown Help View
struct MarkdownHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Markdown Formatting Guide".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 16) {
                    MarkdownHelpItem(
                        title: "Bold Text",
                        syntax: "**Bold**",
                        example: "**This is bold text**",
                        rendered: Text("This is bold text".localized).bold()
                    )
                    
                    MarkdownHelpItem(
                        title: "Italic Text",
                        syntax: "*Italic*",
                        example: "*This is italic text*",
                        rendered: Text("This is italic text".localized).italic()
                    )
                    
                    MarkdownHelpItem(
                        title: "Underlined Text",
                        syntax: "_Underlined_",
                        example: "_This is underlined text_",
                        rendered: Text("This is underlined text".localized).underline()
                    )
                    
                    MarkdownHelpItem(
                        title: "Inline Code",
                        syntax: "`Code`",
                        example: "`let variable = value`",
                        rendered: Text("let variable = value".localized)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    )
                    
                    MarkdownHelpItem(
                        title: "Strikethrough",
                        syntax: "~Strikethrough~",
                        example: "~This is crossed out~",
                        rendered: Text("This is crossed out".localized).strikethrough()
                    )
                    
                    MarkdownHelpItem(
                        title: "Links",
                        syntax: "[Text](URL)",
                        example: "[Visit Apple](https://apple.com)",
                        rendered: Text("Visit Apple".localized)
                            .foregroundColor(.blue)
                            .underline()
                    )
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips:".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("• You can combine formatting: **_Bold and italic_**".localized)
                    Text("• Double-tap the text area to switch between edit and preview modes".localized)
                    Text("• Use the formatting buttons above the keyboard for quick access".localized)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Markdown Help".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Helper view for markdown help items
struct MarkdownHelpItem: View {
    let title: String
    let syntax: String
    let example: String
    let rendered: Text
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Text("Syntax:".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(syntax)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(4)
            }
            
            HStack {
                Text("Example:".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(example)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(4)
            }
            
            HStack {
                Text("Result:".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                rendered
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}






