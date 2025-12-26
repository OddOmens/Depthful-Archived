import SwiftUI
import CoreData
import UIKit

struct Tag: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var color: Color
    
    // Computed property for localized name
    var localizedName: String {
        return name.localized
    }
    
    static var defaultTags: [Tag] = [
        Tag(name: "Advice", color: Color(hex: "#CECDC3")),      // Gray 200
        Tag(name: "Daydream", color: Color(hex: "#B7B5AC")),    // Gray 300
        Tag(name: "Dream", color: Color(hex: "#F89A8A")),       // Coral 200
        Tag(name: "Experience", color: Color(hex: "#E8705F")),  // Coral 300
        Tag(name: "Goal", color: Color(hex: "#F9AE77")),        // Orange 200
        Tag(name: "Gratitude", color: Color(hex: "#EC8B49")),   // Orange 300
        Tag(name: "Idea", color: Color(hex: "#ECCB60")),        // Yellow 200
        Tag(name: "Inspiration", color: Color(hex: "#DFB431")), // Yellow 300
        Tag(name: "Journal", color: Color(hex: "#BEC97E")),     // Green 200
        Tag(name: "Learning", color: Color(hex: "#A0AF54")),    // Green 300
        Tag(name: "Memory", color: Color(hex: "#87D3C3")),      // Teal 200
        Tag(name: "Milestone", color: Color(hex: "#5ABDAC")),   // Teal 300
        Tag(name: "Question", color: Color(hex: "#92BFDB")),    // Blue 200
        Tag(name: "Quote", color: Color(hex: "#66A0C8")),       // Blue 300
        Tag(name: "Reflection", color: Color(hex: "#C4B9E0")),  // Purple 200
        Tag(name: "Regret", color: Color(hex: "#A699D0")),      // Purple 300
        Tag(name: "Story", color: Color(hex: "#F4A4C2")),       // Pink 200
        Tag(name: "Thought", color: Color(hex: "#E47DA8"))      // Pink 300
    ]
    
    static func fromName(_ name: String) -> Tag? {
        return defaultTags.first(where: { $0.name == name }) ?? nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, color
    }
    
    init(id: UUID = UUID(), name: String, color: Color) {
        self.id = id
        self.name = name
        self.color = color
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let colorComponents = try container.decode([CGFloat].self, forKey: .color)
        color = Color(.sRGB, red: colorComponents[0], green: colorComponents[1], blue: colorComponents[2], opacity: colorComponents[3])
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        let colorComponents = color.cgColor?.components ?? [0, 0, 0, 1]
        try container.encode(colorComponents, forKey: .color)
    }
}

class TagManager: ObservableObject {
    @Published var customTags: [Tag]
    @Published var selectedTag: Tag?
    @Published var selectedTags: [Tag] = []
    @Published var lastUpdateTimestamp: Date = Date()
    @Published var recentlyUsedTags: [Tag] = []
    private var viewContext: NSManagedObjectContext

    
    init(viewContext: NSManagedObjectContext) {
        self.customTags = []
        self.selectedTag = nil
        self.selectedTags = []
        self.viewContext = viewContext
        self.recentlyUsedTags = []
        migrateLegacyCustomTagsIfNeeded()
        loadCustomTags()
        loadRecentlyUsedTags()
    }
    
    /// Tries to find and migrate legacy custom tags using several possible UserDefaults keys.
    private func migrateLegacyCustomTagsIfNeeded() {
        let defaults = UserDefaults.standard
        let possibleKeys = ["legacyCustomTags", "customTags", "userCustomTags"]
        
        for key in possibleKeys {
            if let legacyData = defaults.data(forKey: key) {
                let decoder = JSONDecoder()
                if let legacyTags = try? decoder.decode([Tag].self, from: legacyData) {
                    for tag in legacyTags {
                        addCustomTag(tag)
                    }
                    defaults.removeObject(forKey: key)
                    print("Migrated \(legacyTags.count) legacy custom tags from key: \(key)")
                    break
                } else {
                    print("Failed to decode legacy custom tags under the key: \(key)")
                }
            }
        }
    }
    
    /// Saves changes to Core Data.
    private func saveContext() {
        do {
            if viewContext.hasChanges {
                try viewContext.save()
                print("Successfully saved context")
            }
        } catch {
            print("Failed to save context: \(error)")
            viewContext.rollback()
        }
    }
    
    /// Loads custom tags from Core Data and converts them into Tag structs.
    func loadCustomTags() {
        let request: NSFetchRequest<CustomTagEntity> = CustomTagEntity.fetchRequest()
        do {
            let results = try viewContext.fetch(request)
            print("Found \(results.count) custom tags in Core Data")
            
            // Create a dictionary to track unique tags by ID
            var uniqueTags: [UUID: CustomTagEntity] = [:]
            
            // Process each tag and keep only one instance of each ID
            for entity in results {
                if let id = entity.id {
                    if uniqueTags[id] == nil {
                        uniqueTags[id] = entity
                    } else {
                        // If we find a duplicate ID, delete the duplicate
                        print("Deleting duplicate tag with ID: \(id)")
                        viewContext.delete(entity)
                    }
                }
            }
            
            // Save changes if we deleted any duplicates
            if viewContext.hasChanges {
                try viewContext.save()
            }
            
            // Convert remaining unique tags to Tag structs
            self.customTags = uniqueTags.values.map { entity in
                Tag(
                    id: entity.id ?? UUID(),
                    name: entity.name ?? "Untitled",
                    color: Color(
                        red: entity.red,
                        green: entity.green,
                        blue: entity.blue,
                        opacity: entity.opacity
                    )
                )
            }
            
            print("Loaded \(self.customTags.count) unique custom tags")
        } catch {
            print("Failed to load custom tags: \(error)")
        }
    }
    
    /// Adds a new custom tag to Core Data.
    func addCustomTag(_ tag: Tag) {

        let newEntity = CustomTagEntity(context: viewContext)
        newEntity.id = tag.id
        newEntity.name = tag.name
        
        // Convert SwiftUI Color to UIColor to get reliable CGColor components
        let uiColor = UIColor(tag.color)
        let components = uiColor.cgColor.components
        
        if let components = components, components.count >= 4 {
            newEntity.red = Double(components[0])
            newEntity.green = Double(components[1])
            newEntity.blue = Double(components[2])
            newEntity.opacity = Double(components[3])
        } else if let components = components, components.count == 2 {
            // For grayscale colors
            newEntity.red = Double(components[0])
            newEntity.green = Double(components[0])
            newEntity.blue = Double(components[0])
            newEntity.opacity = Double(components[1])
        } else {
            // Fallback values
            newEntity.red = 0
            newEntity.green = 0
            newEntity.blue = 0
            newEntity.opacity = 1
        }
        
        customTags.append(tag)
        saveContext()
    }
    
    /// Updates an existing custom tag.
    func updateCustomTag(_ updatedTag: Tag, oldName: String) {
        let request: NSFetchRequest<CustomTagEntity> = CustomTagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", updatedTag.id as CVarArg)
        do {
            let results = try viewContext.fetch(request)
            if let entityToUpdate = results.first {
                entityToUpdate.name = updatedTag.name
                let uiColor = UIColor(updatedTag.color)
                let components = uiColor.cgColor.components

                if let components = components, components.count >= 4 {
                    entityToUpdate.red = Double(components[0])
                    entityToUpdate.green = Double(components[1])
                    entityToUpdate.blue = Double(components[2])
                    entityToUpdate.opacity = Double(components[3])
                } else if let components = components, components.count == 2 {
                    entityToUpdate.red = Double(components[0])
                    entityToUpdate.green = Double(components[0])
                    entityToUpdate.blue = Double(components[0])
                    entityToUpdate.opacity = Double(components[1])
                }
                saveContext()
            }
            
            if let index = customTags.firstIndex(where: { $0.id == updatedTag.id }) {
                customTags[index] = updatedTag
            }
            
            // Update recently used tags
            if let index = recentlyUsedTags.firstIndex(where: { $0.id == updatedTag.id }) {
                recentlyUsedTags[index] = updatedTag
                saveRecentlyUsedTags()
            }
            
            updateThoughtsWithTag(oldName: oldName, newName: updatedTag.name)
            lastUpdateTimestamp = Date()
        } catch {
            print("Failed to update custom tag: \(error)")
        }
    }
    
    /// Deletes a custom tag from Core Data.
    func deleteCustomTag(_ tag: Tag) {
        let request: NSFetchRequest<CustomTagEntity> = CustomTagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", tag.id as CVarArg)
        do {
            let results = try viewContext.fetch(request)
            for entity in results {
                viewContext.delete(entity)
            }
            saveContext()
            customTags.removeAll { $0.id == tag.id }
            if selectedTag == tag {
                selectedTag = nil
            }
            // Remove from recently used tags
            recentlyUsedTags.removeAll { $0.id == tag.id }
            saveRecentlyUsedTags()
            updateThoughtsWithTag(oldName: tag.name, newName: "")
            lastUpdateTimestamp = Date()
        } catch {
            print("Failed to delete custom tag: \(error)")
        }
    }
    
    func selectSingleTag(_ tag: Tag?) {
        selectedTag = tag
        
        if let tag = tag {
            // Set the selectedTags array to contain only this tag
            selectedTags = [tag]
        } else {
            // Clear the selectedTags array
            selectedTags = []
        }
        
        // Notify listeners that the selection has changed
        lastUpdateTimestamp = Date()
    }
    
    func clearTagSelection() {
        selectedTag = nil
        selectedTags = []
        lastUpdateTimestamp = Date()
    }
    
    func isTagSelected(_ tag: Tag) -> Bool {
        return selectedTags.contains(where: { $0.id == tag.id })
    }
    
    func getTagByName(_ name: String) -> Tag? {
        if let defaultTag = Tag.fromName(name) {
            return defaultTag
        }
        return customTags.first(where: { $0.name == name })
    }
    
    /// Updates thoughts that use the specified tag.
    private func updateThoughtsWithTag(oldName: String, newName: String) {
        let fetchRequest: NSFetchRequest<Thought> = Thought.fetchRequest()
        // Check both tag and tags attributes
        fetchRequest.predicate = NSPredicate(format: "tag == %@ OR tags CONTAINS %@", oldName, oldName)
        do {
            let thoughts = try viewContext.fetch(fetchRequest)
            for thought in thoughts {
                // Update the single tag field
                if thought.tag == oldName {
                    thought.tag = newName
                }
                
                // Update the multiple tags field
                if let tagsString = thought.tags, !tagsString.isEmpty {
                    // Split into array, update the tag, and rejoin
                    let tagArray = tagsString.components(separatedBy: ",")
                    let updatedArray = tagArray.map { $0 == oldName ? newName : $0 }
                    // If newName is empty, filter it out
                    let finalArray = newName.isEmpty ? updatedArray.filter { !$0.isEmpty } : updatedArray
                    thought.tags = finalArray.joined(separator: ",")
                }
            }
            try viewContext.save()
        } catch {
            print("Failed to update thoughts: \(error)")
        }
    }
    
    private func loadRecentlyUsedTags() {
        if let data = UserDefaults.standard.data(forKey: "recentlyUsedTags"),
           let decoded = try? JSONDecoder().decode([Tag].self, from: data) {
            recentlyUsedTags = decoded
        }
    }
    
    private func saveRecentlyUsedTags() {
        if let encoded = try? JSONEncoder().encode(recentlyUsedTags) {
            UserDefaults.standard.set(encoded, forKey: "recentlyUsedTags")
        }
    }
    
    func addToRecentlyUsed(_ tag: Tag) {
        if let index = recentlyUsedTags.firstIndex(where: { $0.id == tag.id }) {
            recentlyUsedTags.remove(at: index)
        }
        recentlyUsedTags.insert(tag, at: 0)
        if recentlyUsedTags.count > 4 {
            recentlyUsedTags.removeLast()
        }
        saveRecentlyUsedTags()
    }
}

struct TagSelectionView: View {
    @ObservedObject var tagManager: TagManager
    let defaultTags: [Tag]
    @Binding var isPresented: Bool
    @Binding var selectedTags: [Tag]
    var hideBackButton: Bool = false  // New property to control back button visibility
    
    @State private var showingTagEditor = false
    @State private var currentTagForEditing: Tag? = nil
    @State private var searchText = ""
    
    // Update grid layout to be more fluid
    private let columns = [
        GridItem(.adaptive(minimum: 10, maximum: .infinity), spacing: 8)
    ]
    
    private var filteredTags: [Tag] {
        if searchText.isEmpty {
            return defaultTags
        }
        return defaultTags.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    private var filteredCustomTags: [Tag] {
        if searchText.isEmpty {
            return tagManager.customTags
        }
        return tagManager.customTags.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    private func isTagSelected(_ tag: Tag) -> Bool {
        return selectedTags.contains(where: { $0.id == tag.id })
    }
    
    private func toggleTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
            tagManager.addToRecentlyUsed(tag)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar at the top - take up full width
            SearchBar(text: $searchText, placeholder: "Search tags...".localized)
                .padding(.vertical, 12)
                .padding(.horizontal, 5)
            
            // Selected Tags Section - Fixed position below search
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Selected Tags".localized)
                            .font(.headline)
                            .foregroundColor(Color.colorPrimary)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                selectedTags.removeAll()
                            }
                        }) {
                            Text("Clear All".localized)
                                .font(.subheadline)
                                .foregroundColor(Color.colorPrimary)
                        }
                    }
                    .padding(.horizontal, 15)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(selectedTags) { tag in
                            TagButton(tag: tag, isSelected: true) {
                                withAnimation {
                                    toggleTag(tag)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                }
                .padding(.vertical, 12)
                
                CustomDivider()
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Tags sections with FlowLayout
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Default Tags
                        if !filteredTags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Default".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 15)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(filteredTags) { tag in
                                        TagButton(tag: tag, isSelected: isTagSelected(tag)) {
                                            withAnimation {
                                                toggleTag(tag)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 15)
                            }
                            .padding(.vertical, 12)
                        }
                        
                        // Custom Tags
                        if !filteredCustomTags.isEmpty {
                            if !filteredTags.isEmpty {
                                CustomDivider()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom Tags".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 15)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(filteredCustomTags) { tag in
                                        TagButton(tag: tag, isSelected: isTagSelected(tag)) {
                                            withAnimation {
                                                toggleTag(tag)
                                            }
                                        }
                                        .contextMenu {
                                            Button("Edit".localized) {
                                                currentTagForEditing = tag
                                                showingTagEditor = true
                                            }
                                            Button("Delete".localized, role: .destructive) {
                                                tagManager.deleteCustomTag(tag)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 15)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
        }
        
        // Custom navigation bar look
        .navigationTitle("Tag Selection".localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Add Tag button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingTagEditor = true
                    currentTagForEditing = nil
                }) {
                    Image("plus")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color.colorPrimary)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
            }
            
            // Custom back button with arrow icon (only if not hidden)
            if !hideBackButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image("arrow-left")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTagEditor) {
            if let tag = currentTagForEditing {
                CustomTagEditorView(tagManager: tagManager, tag: tag)
            } else {
                CustomTagEditorView(tagManager: tagManager)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        
        for row in rows {
            height += row.height
        }
        
        height += spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        
        for row in rows {
            var x = bounds.minX
            
            for element in row.elements {
                let width = element.size.width
                element.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: width, height: element.size.height)
                )
                x += width + spacing
            }
            
            y += row.height + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        
        // Use slightly less than available width to prevent awkward wrapping
        let maxWidth = (proposal.width ?? 0) - 2 // Subtract a small amount to prevent edge issues
        
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            
            if x + size.width > maxWidth && !currentRow.elements.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
                x = 0
            }
            
            currentRow.elements.append(Element(subview: subview, size: size))
            x += size.width + spacing
        }
        
        if !currentRow.elements.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    struct Row {
        var elements: [Element] = []
        
        var height: CGFloat {
            elements.map(\.size.height).max() ?? 0
        }
    }
    
    struct Element {
        let subview: LayoutSubview
        let size: CGSize
    }
}

struct TagButton: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isPressed = false
    
    private var backgroundColor: Color {
        tag.color.opacity(0.75)
    }
    
    private var textColor: Color {
        tag.color.isDark ? .white : .black
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
                action()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            HStack(spacing: 4) {
                Text(tag.localizedName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(textColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(backgroundColor)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? tag.color : tag.color, lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomTagEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var tagManager: TagManager

    // Editable tag properties.
    @State private var tagName: String
    @State private var tagColor: Color

    // For editing, we store the tag's id and the initial name.
    private var tagID: UUID?
    private var isEditing: Bool
    private let initialTagName: String?

    /// Initializer for editing an existing tag.
    init(tagManager: TagManager, tag: Tag) {
        self.tagManager = tagManager
        self._tagName = State(initialValue: tag.name)
        self._tagColor = State(initialValue: tag.color)
        self.tagID = tag.id
        self.isEditing = true
        self.initialTagName = tag.name
    }

    /// Initializer for adding a new tag.
    init(tagManager: TagManager) {
        self.tagManager = tagManager
        self._tagName = State(initialValue: "Custom Tag")
        self._tagColor = State(initialValue: Color.blue)
        self.tagID = nil
        self.isEditing = false
        self.initialTagName = nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Tag Preview (fixed width matching the select tag view)
                TagButton(
                    tag: Tag(id: tagID ?? UUID(), name: tagName, color: tagColor),
                    isSelected: false,
                    action: {}
                )
                .frame(width: 220, height: 50)
                
                // Inline input: Color and Tag Name with their labels above.
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Color".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                        ColorPicker("", selection: $tagColor)
                            .labelsHidden()
                            .frame(width: 50, height: 50)
                            .cornerRadius(5) // Slight rounding; remove if you want completely sharp corners.
                    }
                    VStack(spacing: 8) {
                        Text("Tag Name".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("Enter tag name".localized, text: $tagName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .multilineTextAlignment(.center)
                            .onChange(of: tagName) { oldValue, newValue in
                                if newValue.count > 20 {
                                    tagName = String(newValue.prefix(20))
                                }
                            }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(isEditing ? "Edit Tag".localized : "Custom Tag".localized)
            .toolbar {
                // Back Button on the left.
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image("xmark")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color.colorPrimary)
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                
                        }
                    }
                }
                // Save (Check) icon on the right.
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            let newTag = Tag(id: tagID ?? UUID(), name: tagName, color: tagColor)
                            if isEditing {
                                tagManager.updateCustomTag(newTag, oldName: initialTagName ?? tagName)
                            } else {
                                tagManager.addCustomTag(newTag)
                            }
                            dismiss()
                        }) {
                            Image("check")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(tagName.isEmpty ? Color.gray : Color.colorPrimary)
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                
                        }
                        .disabled(tagName.isEmpty)
                    }
                }
            }
        }
        // Make the sheet shorter using a fraction-based detent.
        .presentationDetents([.fraction(0.35)])
        .presentationDragIndicator(.visible)
    }
}

// Add a TagItemView to handle individual tag appearance
struct TagItemView: View {
    let tag: Tag
    let isSelected: Bool
    
    // Track if this tag has appeared on screen
    @State private var hasAppeared = false
    
    var body: some View {
        Text(tag.localizedName)
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tag.color.opacity(0.8))
            .foregroundColor(tag.color.isDark ? .white : .black)
            .cornerRadius(15)
            .scaleEffect(hasAppeared ? 1 : 0.8)
            .opacity(hasAppeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    hasAppeared = true
                }
            }
            .onDisappear {
                // Reset so it animates again when it scrolls back into view
                hasAppeared = false
            }
    }
}

// Create a separate view for the tag display
struct TagDisplayView: View {
    let selectedTags: [Tag]
    
    var body: some View {
        if selectedTags.isEmpty {
            Text("Select Tags".localized)
                .font(.caption)
                .lineLimit(1)
                .frame(minWidth: 60)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.3))
                .foregroundColor(.black)
                .cornerRadius(15)
        } else if selectedTags.count == 1 {
            let tag = selectedTags[0]
            Text(tag.localizedName)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: 60)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tag.color.opacity(0.8))
                .foregroundColor(tag.color.isDark ? .white : .black)
                .cornerRadius(15)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(selectedTags) { tag in
                        TagItemView(tag: tag, isSelected: false)
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
    }
}

// Create a separate view for all tags display used in detail view
struct DetailTagDisplayView: View {
    var selectedTags: [Tag]
    @AppStorage("showAllTags") private var showAllTags = false
    
    var body: some View {
        if selectedTags.isEmpty {
            Text("No tag".localized)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.3))
                .foregroundColor(.black)
                .cornerRadius(15)
        } else if showAllTags {
            // Show all tags in a scrollable row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(selectedTags, id: \.id) { tag in
                        Text(tag.localizedName)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(tag.color.opacity(0.8))
                            .foregroundColor(tag.color.isDark ? .white : .black)
                            .cornerRadius(15)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        } else {
            // Show first tag with +N indicator
            HStack(spacing: 4) {
                if let firstTag = selectedTags.first {
                    Text(firstTag.localizedName)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(firstTag.color.opacity(0.8))
                        .foregroundColor(firstTag.color.isDark ? .white : .black)
                        .cornerRadius(15)
                    
                    if selectedTags.count > 1 {
                        Text("+\(selectedTags.count - 1)".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.colorNew.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image("search")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.gray)
                .scaledToFit()
                .frame(width: 20, height: 20)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .frame(height: 38)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .frame(width: 20, height: 20)
                }
                .padding(.trailing, 6)
            }
        }
        .padding(.horizontal, 15)
        .background(Color.colorSecondary.opacity(0.15))
        .cornerRadius(10)
        .padding(.horizontal, 10)
    }
}



