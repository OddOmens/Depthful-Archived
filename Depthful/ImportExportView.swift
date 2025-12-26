import SwiftUI
import Foundation
import CoreData
import UniformTypeIdentifiers

class ImportManager {
    static func importThoughts(from url: URL, format: ImportFormat, context: NSManagedObjectContext) {
        switch format {
        case .text:
            importTextFile(url: url, context: context)
        case .markdown:
            importMarkdownFile(url: url, context: context)
        case .csv:
            importCSVFile(url: url, context: context)
        case .customTags:
            importCustomTags(from: url, context: context)
        }
    }

    private static func importTextFile(url: URL, context: NSManagedObjectContext) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.split(separator: "\n")
            var currentTag: String?
            var currentTimestamp = Date()
            
            for line in lines {
                if line.starts(with: "# ") {
                    currentTag = String(line.dropFirst(2))
                } else if line.starts(with: "- ") {
                    let thoughtContent = String(line.dropFirst(2))
                    createThought(content: thoughtContent, tag: currentTag, timestamp: currentTimestamp, context: context)
                    // Increment timestamp slightly to preserve order
                    currentTimestamp = currentTimestamp.addingTimeInterval(1)
                }
            }
        } catch {
            print("Failed to read text file: \(error)")
        }
    }

    private static func importMarkdownFile(url: URL, context: NSManagedObjectContext) {
        importTextFile(url: url, context: context) // Markdown structure is similar to the text structure
    }

    private static func createThought(content: String, tag: String?, timestamp: Date = Date(), context: NSManagedObjectContext) {
        let thought = Thought(context: context)
        thought.content = content
        thought.tag = tag
        thought.timestamp = timestamp
        thought.creationDate = timestamp
        thought.lastUpdated = timestamp
        saveContext(context: context)
    }

    private static func saveContext(context: NSManagedObjectContext) {
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    private static func importCSVFile(url: URL, context: NSManagedObjectContext) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.split(separator: "\n")
            
            // Skip header row
            if lines.count > 1 {
                for i in 1..<lines.count {
                    let line = lines[i]
                    let components = parseCSVLine(String(line))
                    
                    if components.count >= 3 {
                        let thought = Thought(context: context)
                        thought.tag = components[0]
                        thought.content = components[1]
                        
                        let dateFormatter = ISO8601DateFormatter()
                        if let timestamp = dateFormatter.date(from: components[2]) {
                            thought.timestamp = timestamp
                        } else {
                            thought.timestamp = Date()
                        }
                        
                        // Handle optional fields
                        if components.count > 3, let creationDate = dateFormatter.date(from: components[3]) {
                            thought.creationDate = creationDate
                        } else {
                            thought.creationDate = thought.timestamp
                        }
                        
                        if components.count > 4, let lastUpdated = dateFormatter.date(from: components[4]) {
                            thought.lastUpdated = lastUpdated
                        } else {
                            thought.lastUpdated = thought.timestamp
                        }
                        
                        if components.count > 5 {
                            thought.tags = components[5]
                        }
                    }
                }
                
                saveContext(context: context)
            }
        } catch {
            print("Failed to import CSV file: \(error)")
        }
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes = !insideQuotes
            } else if char == "," && !insideQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        // Add the last field
        result.append(currentField)
        
        return result
    }

    private static func importCustomTags(from url: URL, context: NSManagedObjectContext) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.split(separator: "\n")
            
            // Skip header row
            if lines.count > 1 {
                for i in 1..<lines.count {
                    let line = lines[i]
                    let components = parseCSVLine(String(line))
                    
                    if components.count >= 6 {
                        let tag = CustomTagEntity(context: context)
                        tag.name = components[0]
                        tag.red = Double(components[1]) ?? 0.0
                        tag.green = Double(components[2]) ?? 0.0
                        tag.blue = Double(components[3]) ?? 0.0
                        tag.opacity = Double(components[4]) ?? 1.0
                        tag.id = UUID(uuidString: components[5]) ?? UUID()
                    }
                }
                
                saveContext(context: context)
            }
        } catch {
            print("Failed to import custom tags: \(error)")
        }
    }
}

enum ImportFormat {
    case text
    case markdown
    case csv
    case customTags
    
    var title: String {
        switch self {
        case .text: return "Text File".localized
        case .markdown: return "Markdown".localized
        case .csv: return "CSV".localized
        case .customTags: return "Custom Tags".localized
        }
    }
    
    var description: String {
        switch self {
        case .text: return "Simple text format for easy reading".localized
        case .markdown: return "Formatted text with headers and lists".localized
        case .csv: return "Spreadsheet compatible format with all attributes".localized
        case .customTags: return "Import custom tag definitions".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .text, .markdown, .csv: return "file-alt".localized
        case .customTags: return "tags".localized
        }
    }
}

struct ImportOptionsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var viewContext
    @State private var showFilePicker = false
    @State private var selectedURL: URL?
    @State private var selectedFormat: ImportFormat?
    @State private var isImporting = false

    var body: some View {
        List {
            Section {
                ForEach([ImportFormat.text, .markdown, .csv, .customTags], id: \.self) { format in
                    HStack {
                        Image(format.iconName)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundColor(Color.colorPrimary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(format.title)
                                .font(.headline)
                            Text(format.description)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 8)
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFormat = format
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showFilePicker = true
                        }
                    }

                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Import Thoughts".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilePicker, content: {
            DocumentPickerView(url: $selectedURL, allowedTypes: ["public.text"])
                .onDisappear {
                    if let url = selectedURL, let format = selectedFormat {
                        importThoughts(from: url, as: format)
                    }
                }
        })
        .overlay(
            Group {
                if isImporting {
                    ProgressView("Importing...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
        )
    }

    private func importThoughts(from url: URL, as format: ImportFormat) {
        isImporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            ImportManager.importThoughts(from: url, format: format, context: viewContext)
            DispatchQueue.main.async {
                isImporting = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var url: URL?
    var allowedTypes: [String]

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // For iOS 14 and later
        if #available(iOS 14.0, *) {
            let contentTypes: [UTType] = [.text, .plainText, .commaSeparatedText]
            let controller = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
            controller.delegate = context.coordinator
            return controller
        } else {
            // Fallback for older iOS versions
            let controller = UIDocumentPickerViewController(documentTypes: allowedTypes, in: .import)
            controller.delegate = context.coordinator
            return controller
        }
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.url = urls.first
        }
    }
}

class ExportManager {
    static func exportThoughts(context: NSManagedObjectContext, format: ExportFormat) -> [URL] {
        // Fetch thoughts from CoreData
        let fetchRequest: NSFetchRequest<Thought> = Thought.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        do {
            let thoughts = try context.fetch(fetchRequest)
            let groupedThoughts = Dictionary(grouping: thoughts, by: { $0.tag ?? "Untagged" })
            
            switch format {
            case .text:
                let textFileURL = createTextFile(thoughts: groupedThoughts)
                return [textFileURL]
            case .markdown:
                let markdownFileURL = createMarkdownFile(thoughts: groupedThoughts)
                return [markdownFileURL]
            case .csv:
                let csvFileURL = createCSVFile(thoughts: groupedThoughts)
                return [csvFileURL]
            case .customTags:
                let customTagsFileURL = exportCustomTags(context: context)
                return customTagsFileURL.map { [$0] } ?? []
            }
        } catch {
            print("Failed to fetch thoughts: \(error)")
            return []
        }
    }
    
    static func exportSingleThought(thought: Thought, format: ExportFormat) -> URL? {
        let groupedThoughts = ["Single Thought": [thought]]
        
        switch format {
        case .text:
            return createTextFile(thoughts: groupedThoughts)
        case .markdown:
            return createMarkdownFile(thoughts: groupedThoughts)
        case .csv:
            return createCSVFile(thoughts: groupedThoughts)
        case .customTags:
            return nil
        }
    }
    
    private static func createTextFile(thoughts: [String: [Thought]]) -> URL {
        var content = ""
        for (tag, thoughts) in thoughts {
            content.append("# \(tag)\n")
            for thought in thoughts {
                content.append("- \(thought.content ?? "")\n")
            }
            content.append("\n")
        }
        return saveFile(content: content, extension: "txt")
    }
    
    private static func createMarkdownFile(thoughts: [String: [Thought]]) -> URL {
        var content = ""
        for (tag, thoughts) in thoughts {
            content.append("# \(tag)\n")
            for thought in thoughts {
                content.append("- \(thought.content ?? "")\n")
            }
            content.append("\n")
        }
        return saveFile(content: content, extension: "md")
    }
    
    private static func createCSVFile(thoughts: [String: [Thought]]) -> URL {
        var content = "Tag,Content,Timestamp,CreationDate,LastUpdated,Tags\n"
        for (tag, thoughts) in thoughts {
            for thought in thoughts {
                let timestamp = thought.timestamp ?? Date()
                let creationDate = thought.creationDate ?? timestamp
                let lastUpdated = thought.lastUpdated ?? timestamp
                let dateFormatter = ISO8601DateFormatter()
                let timestampString = dateFormatter.string(from: timestamp)
                let creationDateString = dateFormatter.string(from: creationDate)
                let lastUpdatedString = dateFormatter.string(from: lastUpdated)
                
                // Escape quotes in content by doubling them
                let escapedContent = (thought.content ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                let tagsString = thought.tags ?? ""
                
                content.append("\"\(tag)\",\"\(escapedContent)\",\"\(timestampString)\",\"\(creationDateString)\",\"\(lastUpdatedString)\",\"\(tagsString)\"\n")
            }
        }
        return saveFile(content: content, extension: "csv")
    }
    
    private static func saveFile(content: String, extension: String) -> URL {
        let fileName = "ThoughtsExport.\(`extension`)"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to save file: \(error)")
            return URL(fileURLWithPath: "")
        }
    }

    static func exportCustomTags(context: NSManagedObjectContext) -> URL? {
        let fetchRequest: NSFetchRequest<CustomTagEntity> = CustomTagEntity.fetchRequest()
        
        do {
            let tags = try context.fetch(fetchRequest)
            var content = "Name,Red,Green,Blue,Opacity,ID\n"
            
            for tag in tags {
                let name = tag.name ?? ""
                let red = tag.red
                let green = tag.green
                let blue = tag.blue
                let opacity = tag.opacity
                let id = tag.id?.uuidString ?? UUID().uuidString
                
                content.append("\"\(name)\",\(red),\(green),\(blue),\(opacity),\"\(id)\"\n")
            }
            
            return saveFile(content: content, extension: "csv")
        } catch {
            print("Failed to fetch custom tags: \(error)")
            return nil
        }
    }
}

enum ExportFormat: CaseIterable {
    case text
    case markdown
    case csv
    case customTags
    
    static var allCases: [ExportFormat] = [.text, .markdown, .csv, .customTags]
    
    var title: String {
        switch self {
        case .text: return "Text File".localized
        case .markdown: return "Markdown".localized
        case .csv: return "CSV".localized
        case .customTags: return "Custom Tags".localized
        }
    }
    
    var description: String {
        switch self {
        case .text: return "Simple text format for easy reading".localized
        case .markdown: return "Formatted text with headers and lists".localized
        case .csv: return "Spreadsheet compatible format with all attributes".localized
        case .customTags: return "Export custom tag definitions".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .text, .markdown, .csv: return "file-alt".localized
        case .customTags: return "file-alt".localized
        }
    }
}

// Helper view for presenting the share sheet
struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {}
}

struct ExportOptionsView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    @State private var exportedFiles: [URL] = []
    @State private var isExporting = false // Loading indicator state
    let thought: Thought?
    
    var body: some View {
        List {
            Section {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    HStack {
                        Image(format.iconName)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundColor(Color.colorPrimary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(format.title)
                                .font(.headline)
                            Text(format.description)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 8)
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        exportThoughts(as: format)
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Export Thoughts".localized)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            Group {
                if isExporting {
                    ProgressView("Exporting...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
        )
        .sheet(isPresented: $showShareSheet, onDismiss: {
            exportedFiles = [] // Cleanup after dismissal
        }) {
            if !exportedFiles.isEmpty {
                ActivityView(activityItems: exportedFiles)
            }
        }
    }
    
    private func exportThoughts(as format: ExportFormat) {
        isExporting = true
        exportedFiles = [] // Reset state

        DispatchQueue.global(qos: .userInitiated).async {
            var files: [URL] = []

            // Export logic
            if format == .customTags {
                if let url = ExportManager.exportCustomTags(context: viewContext) {
                    if FileManager.default.fileExists(atPath: url.path) {
                        files = [url]
                    }
                }
            } else if let thought = thought {
                if let url = ExportManager.exportSingleThought(thought: thought, format: format) {
                    if FileManager.default.fileExists(atPath: url.path) {
                        files = [url]
                    } else {
                        print("File not found: \(url.path)")
                    }
                }
            } else {
                let exported = ExportManager.exportThoughts(context: viewContext, format: format)
                files = exported.filter { FileManager.default.fileExists(atPath: $0.path) }
            }

            DispatchQueue.main.async {
                isExporting = false // Hide progress indicator
                exportedFiles = files
                
                if !exportedFiles.isEmpty {
                    // Show share sheet after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showShareSheet = true
                    }
                } else {
                    print("Export failed: no files available.")
                }
            }
        }
    }
}

