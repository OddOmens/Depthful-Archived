import SwiftUI
import CoreData
import UIKit
import StoreKit
import Charts // Import the Charts framework
import PhotosUI

// Simple markdown renderer for list view
struct SimpleMarkdownText: View {
    let text: String
    let lineLimit: Int?
    
    var body: some View {
        Text(parseBasicMarkdown(text))
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
    }
    
    private func parseBasicMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        
        // Handle links first [text](url) - need to handle these before other formatting
        result = applyLinkPattern(to: result)
        
        // Handle bold **text**
        result = applyMarkdownPattern(to: result, pattern: #"\*\*([^*]+)\*\*"#) { content in
            var attributed = AttributedString(content)
            attributed.font = .body.bold()
            return attributed
        }
        
        // Handle italic *text*
        result = applyMarkdownPattern(to: result, pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#) { content in
            var attributed = AttributedString(content)
            attributed.font = .body.italic()
            return attributed
        }
        
        // Handle underline _text_
        result = applyMarkdownPattern(to: result, pattern: #"_([^_]+)_"#) { content in
            var attributed = AttributedString(content)
            attributed.underlineStyle = .single
            return attributed
        }
        
        // Handle code `text`
        result = applyMarkdownPattern(to: result, pattern: #"`([^`]+)`"#) { content in
            var attributed = AttributedString(content)
            attributed.font = .body.monospaced()
            attributed.foregroundColor = .secondary
            return attributed
        }
        
        // Handle strikethrough ~text~
        result = applyMarkdownPattern(to: result, pattern: #"~([^~]+)~"#) { content in
            var attributed = AttributedString(content)
            attributed.strikethroughStyle = .single
            return attributed
        }
        
        return result
    }
    
    private func applyLinkPattern(to attributedString: AttributedString) -> AttributedString {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#) else {
            return attributedString
        }
        
        let string = String(attributedString.characters)
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
        
        var result = attributedString
        
        // Process matches in reverse order to maintain indices
        for match in matches.reversed() {
            guard match.numberOfRanges > 2,
                  let fullRange = Range(match.range, in: string),
                  let textRange = Range(match.range(at: 1), in: string),
                  let urlRange = Range(match.range(at: 2), in: string) else {
                continue
            }
            
            let linkText = String(string[textRange])
            let linkURL = String(string[urlRange])
            
            // Create attributed string for the link
            var linkAttributed = AttributedString(linkText)
            linkAttributed.foregroundColor = .blue
            linkAttributed.underlineStyle = .single
            
            // Add the URL as a link if it's a valid URL
            if let url = URL(string: linkURL) {
                linkAttributed.link = url
            }
            
            // Find the corresponding range in the AttributedString
            if let attributedRange = findRange(in: result, for: fullRange, in: string) {
                result.replaceSubrange(attributedRange, with: linkAttributed)
            }
        }
        
        return result
    }
    
    private func applyMarkdownPattern(to attributedString: AttributedString, pattern: String, transform: (String) -> AttributedString) -> AttributedString {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return attributedString
        }
        
        let string = String(attributedString.characters)
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
        
        var result = attributedString
        
        // Process matches in reverse order to maintain indices
        for match in matches.reversed() {
            guard match.numberOfRanges > 1,
                  let fullRange = Range(match.range, in: string),
                  let contentRange = Range(match.range(at: 1), in: string) else {
                continue
            }
            
            let content = String(string[contentRange])
            let transformedContent = transform(content)
            
            // Find the corresponding range in the AttributedString
            if let attributedRange = findRange(in: result, for: fullRange, in: string) {
                result.replaceSubrange(attributedRange, with: transformedContent)
            }
        }
        
        return result
    }
    
    private func findRange(in attributedString: AttributedString, for range: Range<String.Index>, in originalString: String) -> Range<AttributedString.Index>? {
        let startOffset = range.lowerBound.utf16Offset(in: originalString)
        let endOffset = range.upperBound.utf16Offset(in: originalString)
        
        let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: startOffset)
        let endIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: endOffset)
        
        guard startIndex <= endIndex else {
            return nil
        }
        
        return startIndex..<endIndex
    }
}

enum ViewMode {
    case list
    case grid
}

struct ThoughtsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var tagManager: TagManager
    @State private var editingThought: Thought?
    @State private var searchText = ""
    @State private var showTagSelection = false
    @State private var showUntagged = false
    @State private var viewMode: ViewMode = .list
    @State private var selectedForDeletion: Thought?
    @State private var navigateToThoughtDetail = false
    @State private var refreshID = UUID()
    @State private var isLoading = true
    @State private var showAnalytics = false
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showSubscription = false
    @State private var showSortOptions = false
    @State private var sortOption: SortOption = .newestFirst
    @AppStorage("showFullThought") private var showFullThought = false
    @AppStorage("showPhotos") private var showPhotos = true
    @AppStorage("showAllTags") private var showAllTags = false
    @AppStorage("showTimestamps") private var showTimestamps = true
    @AppStorage("showImageCount") private var showImageCount = true
    @AppStorage("showRecordingCount") private var showRecordingCount = true
    @State private var thoughtToDelete: Thought?
    @State private var showDeleteConfirmation = false
    @State private var showSearchBar = false
    @State private var languageChangeID = UUID() // Force refresh when language changes
    
    // Parameters for widget deep links
    var shouldCreateNewThought: Bool
    var thoughtURLToOpen: URL?

    @FetchRequest var filteredThoughts: FetchedResults<Thought>

    // Define sort options
    enum SortOption: String, CaseIterable, Identifiable {
        case newestFirst = "Newest First"
        case oldestFirst = "Oldest First"
        case lastViewedFirst = "Recently Viewed"
        case lastViewedLast = "Least Recently Viewed"
        case alphabetical = "A to Z"
        case reverseAlphabetical = "Z to A"
        
        var id: String { self.rawValue }
        
        var displayName: String {
            return self.rawValue.localized
        }
        
        var sortDescriptors: [SortDescriptor<Thought>] {
            // Always prioritize favorites at the top
            
            switch self {
            case .newestFirst:
                return [
                    SortDescriptor(\Thought.favorite, order: .reverse),
                    SortDescriptor(\Thought.creationDate, order: .reverse)
                ]
            case .oldestFirst:
                return [
                    SortDescriptor(\Thought.favorite, order: .reverse),
                    SortDescriptor(\Thought.creationDate, order: .forward)
                ]
            case .lastViewedFirst:
                return [
                    SortDescriptor(\Thought.favorite, order: .reverse),
                    SortDescriptor(\Thought.timestamp, order: .reverse)
                ]
            case .lastViewedLast:
                return [
                    SortDescriptor(\Thought.favorite, order: .reverse),
                    SortDescriptor(\Thought.timestamp, order: .forward)
                ]
            case .alphabetical:
                return [
                    SortDescriptor(\Thought.favorite, order: .reverse),
                    SortDescriptor(\Thought.content, order: .forward)
                ]
            case .reverseAlphabetical:
                return [
                    SortDescriptor(\Thought.favorite, order: .reverse),
                    SortDescriptor(\Thought.content, order: .reverse)
                ]
            }
        }
    }

    private var noContentMessageForTag: String {
        if !tagManager.selectedTags.isEmpty {
            if tagManager.selectedTags.count == 1 {
                return "No thoughts with tag '\(tagManager.selectedTags[0].name)'"
            } else {
                let tagNames = tagManager.selectedTags.map { $0.name }.joined(separator: ", ")
                return "No thoughts with all tags: \(tagNames)"
            }
        } else if showUntagged {
            return "No untagged thoughts"
        } else if !searchText.isEmpty {
            return "No thoughts match '\(searchText)'"
        } else {
            return "No thoughts yet"
        }
    }
    
    init(shouldCreateNewThought: Bool = false, thoughtURLToOpen: URL? = nil) {
        let tagManager = TagManager(viewContext: PersistenceController.shared.container.viewContext)
        
        // Initialize fetch request with default parameters
        _filteredThoughts = FetchRequest<Thought>(sortDescriptors: [
            SortDescriptor(\Thought.favorite, order: .reverse),
            SortDescriptor(\Thought.creationDate, order: .reverse)
        ])
        
        _tagManager = StateObject(wrappedValue: tagManager)
        
        // Initialize parameters for widget deep links
        self.shouldCreateNewThought = shouldCreateNewThought
        self.thoughtURLToOpen = thoughtURLToOpen
    }
    
    func titleForTag(_ tags: [Tag]) -> String {
        let thoughtCount = filteredThoughts.count
        
        let thoughtWord = thoughtCount == 1 ? "Thought".localized : "Thoughts".localized
        
        if tags.isEmpty {
            return String(format: "%@ %lld %@", "Found".localized, thoughtCount, thoughtWord)
        } else if tags.count == 1 {
            return String(format: "'%@': %lld %@", tags[0].localizedName, thoughtCount, thoughtWord)
        } else {
            return String(format: "%lld %@: %lld %@", tags.count, "Tags".localized, thoughtCount, thoughtWord)
        }
    }
    
    // Computed property to force refresh when needed
    private var titleText: String {
        // Include languageChangeID to force refresh when language changes
        _ = languageChangeID
        return titleForTag(tagManager.selectedTags)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                Group {
                    if isLoading {
                        ProgressView("Loading...")
                    } else {
                        VStack {
                            if filteredThoughts.isEmpty {
                                EmptyStateView(
                                    message: noContentMessageForTag,
                                    createNewThought: createNewThought,
                                    tagManager: tagManager
                                )
                            } else {
                                List {
                                    ForEach(filteredThoughts, id: \.objectID) { thought in
                                        ThoughtItemView(
                                            thought: thought,
                                            tagManager: tagManager,
                                            onDelete: { thought in
                                                thoughtToDelete = thought
                                                showDeleteConfirmation = true
                                            },
                                            showFullThought: showFullThought,
                                            showPhotos: showPhotos,
                                            showAllTags: showAllTags,
                                            showTimestamps: showTimestamps,
                                            showImageCount: showImageCount,
                                            showRecordingCount: showRecordingCount
                                        )
                                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                thoughtToDelete = thought
                                                showDeleteConfirmation = true
                                            } label: {
                                                Label("Delete".localized, systemImage: "trash")
                                            }
                                        }
                                        .onTapGesture {
                                            editingThought = thought
                                            navigateToThoughtDetail = true
                                        }
                                    }
                                }
                                .listStyle(.plain)
                                .scrollContentBackground(.hidden)
                                .contentMargins(.bottom, 80) // Add bottom margin for overlay
                                
                            }
                        }
                    }
                }
            }
            .id(refreshID)
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                // Search bar overlay
                if showSearchBar {
                    HStack(spacing: 12) {
                        TextField("Search your thoughts...".localized, text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.clear)
                                .onSubmit {
                                    // Handle search submission if needed
                                }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                updateFetchRequest()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect()
                    .offset(y: -8)
                    .scaleEffect(showSearchBar ? 1.0 : 0.1)
                    .opacity(showSearchBar ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0), value: showSearchBar)
                    .zIndex(1)
                    .padding(.horizontal, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(SortOption.allCases) { option in
                            Button(action: {
                                sortOption = option
                                updateSortOrder()
                            }) {
                                Label {
                                    Text(option.displayName)
                                } icon: {
                                    if option == sortOption {
                                        Image("circle-check-alt")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image("circle")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image("arrow-down-arrow-up")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color.colorPrimary)
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // Display options section
                        Section {
                            Button(action: {
                                showFullThought.toggle()
                            }) {
                                Label {
                                    Text("Show Full Text".localized)
                                } icon: {
                                    if showFullThought {
                                        Image("circle-check-alt")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image("circle")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                            
                            Button(action: {
                                showPhotos.toggle()
                            }) {
                                Label {
                                    Text("Show Photos".localized)
                                } icon: {
                                    if showPhotos {
                                        Image("circle-check-alt")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image("circle")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }

                            Button(action: {
                                showImageCount.toggle()
                            }) {
                                Label {
                                    Text("Show Image Count".localized)
                                } icon: {
                                    if showImageCount {
                                        Image("circle-check-alt")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image("circle")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }

                            Button(action: {
                                showRecordingCount.toggle()
                            }) {
                                Label {
                                    Text("Show Recording Count".localized)
                                } icon: {
                                    if showRecordingCount {
                                        Image("circle-check-alt")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image("circle")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }

                            Button(action: {
                                showAllTags.toggle()
                            }) {
                                Label {
                                    Text("Show All Tags".localized)
                                } icon: {
                                    if showAllTags {
                                        Image("circle-check-alt")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image("circle")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                            
                            Button(action: {
                                showTimestamps.toggle()
                            }) {
                                Label {
                                    Text("Show Timestamps".localized)
                                } icon: {
                                    if showTimestamps {
                                        Image("circle-check-alt")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image("circle")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Color.colorPrimary)
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                        } header: {
                            Text("Display Options".localized)
                        }
                        
                        // Analytics section
                        Section {
                            Button(action: {
                                showAnalytics = true
                            }) {
                                Label {
                                    Text("Analytics".localized)
                                } icon: {
                                    Image("chart-line")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(Color.colorPrimary)
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                }
                            }
                        } header: {
                            Text("Tools".localized)
                        }
                        
                        // Settings section
                        Section {
                            NavigationLink(destination: SettingsView(themeManager: themeManager, tagManager: tagManager)
                                .environment(\.managedObjectContext, viewContext)) {
                                Label {
                                    Text("Settings".localized)
                                } icon: {
                                    Image("gear")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(Color.colorPrimary)
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                }
                            }
                        } header: {
                            Text("Preferences".localized)
                        }
                    } label: {
                        HStack {
                            Image("dots-horizontal")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color.colorPrimary)
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                
                        }
                    }
                }
                
                // Bottom toolbar items
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    
                    HStack(spacing: 30) {
                        Button(action: {
                            self.showTagSelection.toggle()
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image("tag")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(Color.colorPrimary)
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                                    
                                    .padding(.leading, 5)
                                
                                // Show tag count badge when multiple tags are selected
                                if tagManager.selectedTags.count > 1 {
                                    Text("\(tagManager.selectedTags.count)".localized)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Circle().fill(Color.colorNew))
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .frame(width: 32, height: 32)
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSearchBar.toggle()
                            }
                        }) {
                            Image("search")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(showSearchBar ? Color.colorNew : Color.colorPrimary)
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                
                        }
                        .frame(width: 32, height: 32)
                        
                        NavigationLink(destination: ThoughtDetailView(
                            thought: .constant(nil),
                            tagManager: tagManager,
                            selectedFilterTags: Binding(
                                get: { tagManager.selectedTags },
                                set: { tagManager.selectedTags = $0 }
                            ),
                            onSave: {
                                refreshView()
                            })
                            .environment(\.managedObjectContext, self.viewContext)) {
                                Image("plus")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(Color.colorPrimary)
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                                    .padding(.trailing, 5)

                            }
                            .frame(width: 32, height: 32)
                    }
                    
                    Spacer()
                }
            }
            .toolbarBackground(.hidden, for: .bottomBar)
            .onChange(of: tagManager.lastUpdateTimestamp) { oldValue, newValue in
                refreshView()
            }
            .onChange(of: searchText) { oldValue, newValue in
                updateFetchRequest()
            }
            .onChange(of: tagManager.selectedTags) { oldValue, newValue in
                showUntagged = false
                updateFetchRequest()
                // Force refresh the view when tag selection changes
                refreshID = UUID()
            }
            .navigationDestination(isPresented: $navigateToThoughtDetail) {
                ThoughtDetailView(thought: $editingThought, tagManager: tagManager, selectedFilterTags: Binding(
                    get: { tagManager.selectedTags },
                    set: { tagManager.selectedTags = $0 }
                ), onSave: {
                    refreshView()
                })
                .environment(\.managedObjectContext, viewContext)
            }
            .navigationDestination(isPresented: $showTagSelection) {
                NavigationStack {
                    TagSelectionView(
                        tagManager: tagManager,
                        defaultTags: Tag.defaultTags,
                        isPresented: $showTagSelection,
                        selectedTags: Binding(
                            get: { tagManager.selectedTags },
                            set: { tagManager.selectedTags = $0 }
                        )
                    )
                }
            }
            .task {
                // Handle URL scheme parameters on load
                if shouldCreateNewThought {
                    createNewThought()
                } else if let url = thoughtURLToOpen {
                    openThoughtFromURL(url)
                }
            }
            .onAppear {
                // Remove delay and set loading state immediately
                isLoading = false
                
                // Add notification observer for language changes
                NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    // Force refresh translations
                    languageChangeID = UUID()
                }
                
                // Also listen for locale changes
                NotificationCenter.default.addObserver(
                    forName: NSLocale.currentLocaleDidChangeNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    // Force refresh translations
                    languageChangeID = UUID()
                }
            }
            .onDisappear {
                // Remove notification observers
                NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: NSLocale.currentLocaleDidChangeNotification, object: nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                print("⚠️ MEMORY WARNING: Clearing caches and forcing garbage collection")
                // Force refresh Core Data context to free memory
                viewContext.refreshAllObjects()
                // Update language change ID to force view refresh and memory cleanup
                languageChangeID = UUID()
            }
            .sheet(isPresented: $showAnalytics) {
                AnalyticsView(viewContext: viewContext)
            }
            .alert("Delete Thought".localized, isPresented: $showDeleteConfirmation) {
                Button("Cancel".localized, role: .cancel) {
                    thoughtToDelete = nil
                }
                Button("Delete".localized, role: .destructive) {
                    if let thought = thoughtToDelete {
                        deleteThought(thought)
                        thoughtToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this thought? This action cannot be undone.".localized)
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }

    private func deleteThoughts(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredThoughts[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
                
            } catch {
                print("Error deleting thought: \(error)")
            }
        }
    }

    private func deleteThought(_ thought: Thought) {
        viewContext.delete(thought)
        do {
            try viewContext.save()
            
            
            // No need to call refreshView() here as the FetchRequest will automatically update
        } catch {
            print("Error deleting thought: \(error)")
            viewContext.rollback()
        }
    }

    private func refreshView() {
        updateFetchRequest()
        refreshID = UUID()
    }

    private func updateFetchRequest() {
        var predicates: [NSPredicate] = []

        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "content CONTAINS[c] %@", searchText))
        }

        if !tagManager.selectedTags.isEmpty {
            var tagPredicates: [NSPredicate] = []
            
            // Create a predicate for each selected tag
            for tag in tagManager.selectedTags {
                // For each tag, check:
                // 1. If it's in the 'tag' field (single tag, legacy support)
                // 2. If it's exactly equal to the entire 'tags' field
                // 3. If it's at the start of 'tags' field followed by a comma 
                // 4. If it's in the middle of 'tags' field with commas on both sides
                // 5. If it's at the end of 'tags' field preceded by a comma
                tagPredicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "tag == %@", tag.name),
                    NSPredicate(format: "tags == %@", tag.name),
                    NSPredicate(format: "tags BEGINSWITH %@", "\(tag.name),"),
                    NSPredicate(format: "tags CONTAINS %@", ",\(tag.name),"),
                    NSPredicate(format: "tags ENDSWITH %@", ",\(tag.name)")
                ]))
            }
            
            // Thoughts must match ALL selected tags (AND relationship)
            predicates.append(NSCompoundPredicate(andPredicateWithSubpredicates: tagPredicates))
        } else if showUntagged {
            predicates.append(NSPredicate(format: "(tag == nil OR tag == '') AND (tags == nil OR tags == '')"))
        }

        filteredThoughts.nsPredicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        // Apply current sort option (always with favorites at the top)
        updateSortOrder()
    }
    
    private func updateSortOrder() {
        filteredThoughts.sortDescriptors = sortOption.sortDescriptors
    }
    
    private func createNewThought() {
        editingThought = nil
        navigateToThoughtDetail = true
    }

    private func openThoughtFromURL(_ url: URL) {
        // URL format is depthful://open-thought/[thought-uri]
        let path = url.path
        
        // Convert the URL encoded objectID back to an actual NSURL
        if let thoughtURIString = path.split(separator: "/").last,
           let thoughtURI = URL(string: String(thoughtURIString)),
           let objectID = persistenceController.container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: thoughtURI) {
            
            // Fetch the thought with this objectID
            if let thought = try? viewContext.existingObject(with: objectID) as? Thought {
                editingThought = thought
                navigateToThoughtDetail = true
            }
        }
    }

    private var persistenceController: PersistenceController {
        PersistenceController.shared
    }
}

// Parse images from the new combined data format
private func parseImageData(_ data: Data) -> [UIImage]? {
    guard data.count > 4 else {
        return nil
    }
    
    var offset = 0
    var images: [UIImage] = []
    
    // Read metadata size
    let metadataSize = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    offset += 4
    
    guard offset + Int(metadataSize) <= data.count else {
        return nil
    }
    
    // Skip metadata (we don't need it for loading)
    offset += Int(metadataSize)
    
    // Read individual images
    while offset < data.count {
        // Read image size
        guard offset + 4 <= data.count else { break }
        let imageSize = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        offset += 4
        
        // Read image data
        guard offset + Int(imageSize) <= data.count else {
            break
        }
        
        let imageData = data.subdata(in: offset..<offset+Int(imageSize))
        offset += Int(imageSize)
        
        // Create UIImage
        if let image = UIImage(data: imageData) {
            images.append(image)
        }
    }
    
    return images.isEmpty ? nil : images
}

struct ThoughtItemView: View {
    var thought: Thought
    var tagManager: TagManager
    var onDelete: ((Thought) -> Void)?
    var showFullThought: Bool
    var showPhotos: Bool
    var showAllTags: Bool
    var showTimestamps: Bool
    var showImageCount: Bool
    var showRecordingCount: Bool
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var loadedImages: [UIImage] = []
    @State private var recordingsCount: Int = 0
    
    private var formattedTimestamp: String {
        guard let timestamp = thought.timestamp else { return "Unviewed" }
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day, .month, .year], from: timestamp, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)y ago"
        }
        if let months = components.month, months > 0 {
            return "\(months)mo ago"
        }
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        }
        if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        }
        if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        }
        return "Just now"
    }
    
    private func loadImages() {
        // Check if thought has images data
        guard let imageData = thought.images else {
            return
        }
        
        // Try the new combined data format first
        if let images = parseImageData(imageData) {
            DispatchQueue.main.async {
                loadedImages = images
            }
            return
        }
        
        // Try standard UIImage array approach
        if let images = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: imageData) as? [UIImage] {
            DispatchQueue.main.async {
                loadedImages = images
            }
            return
        }
        
        // Try data array conversion approach
        if let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: imageData) {
            unarchiver.requiresSecureCoding = true
            
            if let imageDataArray = unarchiver.decodeObject(of: [NSArray.self, NSData.self], forKey: "images") as? [Data] {
                let convertedImages = imageDataArray.compactMap { UIImage(data: $0) }
                DispatchQueue.main.async {
                    loadedImages = convertedImages
                }
            }
        }
    }
    
    private func loadRecordingsCount() {
        let request = VoiceRecording.fetchRequest()
        request.predicate = NSPredicate(format: "thought == %@", thought)
        
        do {
            recordingsCount = try viewContext.count(for: request)
        } catch {
            print("Failed to fetch recordings count: \(error)")
            recordingsCount = 0
        }
    }
    
    private func toggleFavorite() {
        thought.favorite.toggle()
        
        do {
            try viewContext.save()
            print("Successfully toggled favorite to: \(thought.favorite)")
        } catch {
            print("Failed to save favorite status: \(error)")
            viewContext.rollback()
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image preview if available and showPhotos is true
            if !loadedImages.isEmpty && showPhotos {
                // Show fixed grid of up to 4 images with +N counter for the 5th+ images
                HStack(spacing: 8) {
                    ForEach(loadedImages.prefix(4).indices, id: \.self) { index in
                        Image(uiImage: loadedImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if loadedImages.count > 4 {
                        Text("+\(loadedImages.count - 4)".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.colorNew.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(height: 60)
            }

            SimpleMarkdownText(
                text: thought.content ?? "",
                lineLimit: showFullThought ? nil : 3
            )
            .font(.body)
            
            HStack {
                // Bookmark moved to the left
                Button(action: {
                    toggleFavorite()
                }) {
                    Image(thought.favorite ? "bookmark-fill" : "bookmark")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(Color.colorPrimary)
                }
                .buttonStyle(PlainButtonStyle())

                // Display tags from the tags string (comma-separated)
                if let tagsString = thought.tags, !tagsString.isEmpty {
                    let tagNames = tagsString.components(separatedBy: ",")
                    
                    if showAllTags {
                        // Show all tags in a wrapped flow
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(tagNames, id: \.self) { tagName in
                                    if let tag = tagManager.getTagByName(tagName) {
                                        Text(tag.localizedName)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(tag.color.opacity(0.8))
                                            .foregroundColor(tag.color.isDark ? .white : .black)
                                            .cornerRadius(15)
                                    } else {
                                        Text(tagName)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.gray.opacity(0.3))
                                            .foregroundColor(.black)
                                            .cornerRadius(15)
                                    }
                                }
                            }
                        }
                    } else {
                        // Show first tag with +N indicator
                        HStack(spacing: 4) {
                            if let firstTagName = tagNames.first, let firstTag = tagManager.getTagByName(firstTagName) {
                                Text(firstTag.localizedName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(firstTag.color.opacity(0.8))
                                    .foregroundColor(firstTag.color.isDark ? .white : .black)
                                    .cornerRadius(15)
                                
                                if tagNames.count > 1 {
                                    Text("+\(tagNames.count - 1)".localized)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.colorNew.opacity(0.9))
                                        .foregroundColor(.white)
                                        .cornerRadius(15)
                                }
                            }
                        }
                    }
                } else if let singleTag = thought.tag, !singleTag.isEmpty {
                    // Legacy single tag support
                    if let tag = tagManager.getTagByName(singleTag) {
                        Text(tag.localizedName)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tag.color.opacity(0.8))
                            .foregroundColor(tag.color.isDark ? .white : .black)
                            .cornerRadius(15)
                    } else {
                        Text(singleTag)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.black)
                            .cornerRadius(15)
                    }
                } else {
                    Text("No tag".localized)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.black)
                        .cornerRadius(15)
                }

                // Media indicators
                if !loadedImages.isEmpty && showImageCount {
                    HStack(spacing: 4) {
                        Image("image-square")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("\(loadedImages.count)".localized)
                            .font(.caption)
                            .foregroundColor(Color.colorPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.colorPrimary.opacity(0.1))
                    .cornerRadius(15)
                }
                
                if recordingsCount > 0 && showRecordingCount {
                    HStack(spacing: 4) {
                        Image("microphone-alt-1")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("\(recordingsCount)".localized)
                            .font(.caption)
                            .foregroundColor(Color.colorPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.colorPrimary.opacity(0.1))
                    .cornerRadius(15)
                }
                
                Spacer()
                
                if showTimestamps {
                    Text(formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
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
        .onAppear {
            loadImages()
            loadRecordingsCount()
        }
    }
}

struct StaggeredGridView: View {
    var thoughts: [Thought]
    var tagManager: TagManager
    var onTap: (Thought) -> Void
    var onDelete: (Thought) -> Void
    @Binding var selectedForDeletion: Thought?
    var showFullThought: Bool
    var showPhotos: Bool
    var showAllTags: Bool
    var showTimestamps: Bool
    var showImageCount: Bool
    var showRecordingCount: Bool
    @State private var thoughtToDelete: Thought?
    @State private var showDeleteConfirmation = false

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let columnWidth = (screenWidth / 2) - 20
        
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<thoughts.count, id: \.self) { index in
                    if index % 2 == 0 {
                        ThoughtGridItem(
                            thought: thoughts[index],
                            tagManager: tagManager,
                            width: columnWidth,
                            onTap: onTap,
                            onDelete: { thought in
                                thoughtToDelete = thought
                                showDeleteConfirmation = true
                            },
                            selectedForDeletion: $selectedForDeletion,
                            showFullThought: showFullThought,
                            showPhotos: showPhotos,
                            showAllTags: showAllTags,
                            showTimestamps: showTimestamps,
                            showImageCount: showImageCount,
                            showRecordingCount: showRecordingCount
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTap(thoughts[index])
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<thoughts.count, id: \.self) { index in
                    if index % 2 != 0 {
                        ThoughtGridItem(
                            thought: thoughts[index],
                            tagManager: tagManager,
                            width: columnWidth,
                            onTap: onTap,
                            onDelete: { thought in
                                thoughtToDelete = thought
                                showDeleteConfirmation = true
                            },
                            selectedForDeletion: $selectedForDeletion,
                            showFullThought: showFullThought,
                            showPhotos: showPhotos,
                            showAllTags: showAllTags,
                            showTimestamps: showTimestamps,
                            showImageCount: showImageCount,
                            showRecordingCount: showRecordingCount
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTap(thoughts[index])
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 15)
        .alert("Delete Thought".localized, isPresented: $showDeleteConfirmation) {
            Button("Cancel".localized, role: .cancel) {
                thoughtToDelete = nil
            }
            Button("Delete".localized, role: .destructive) {
                if let thought = thoughtToDelete {
                    onDelete(thought)
                    thoughtToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this thought? This action cannot be undone.".localized)
        }
    }
}

struct ThoughtGridItem: View {
    var thought: Thought
    var tagManager: TagManager
    var width: CGFloat
    var onTap: (Thought) -> Void
    var onDelete: (Thought) -> Void
    @Binding var selectedForDeletion: Thought?
    var showFullThought: Bool
    var showPhotos: Bool
    var showAllTags: Bool
    var showTimestamps: Bool
    var showImageCount: Bool
    var showRecordingCount: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showDeleteButton = false
    @State private var timer: Timer?
    @State private var isWiggling = false
    @State private var showDeleteConfirmation = false
    
    @State private var loadedImages: [UIImage] = []
    
    private let wiggleAnimation = Animation.easeInOut(duration: 0.15).repeatForever(autoreverses: true)
    
    private func loadImages() {
        // Check if thought has images data
        guard let imageData = thought.images else {
            return
        }
        
        // Try the new combined data format first
        if let images = parseImageData(imageData) {
            DispatchQueue.main.async {
                loadedImages = images
            }
            return
        }
        
        // Try standard UIImage array approach
        if let images = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: imageData) as? [UIImage] {
            DispatchQueue.main.async {
                loadedImages = images
            }
            return
        }
        
        // Try data array conversion approach
        if let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: imageData) {
            unarchiver.requiresSecureCoding = true
            
            if let imageDataArray = unarchiver.decodeObject(of: [NSArray.self, NSData.self], forKey: "images") as? [Data] {
                let convertedImages = imageDataArray.compactMap { UIImage(data: $0) }
                DispatchQueue.main.async {
                    loadedImages = convertedImages
                }
            }
        }
    }
    
    private func toggleFavorite() {
        thought.favorite.toggle()
        
        do {
            try viewContext.save()
            print("Successfully toggled favorite to: \(thought.favorite)")
        } catch {
            print("Failed to save favorite status: \(error)")
            viewContext.rollback()
        }
    }
    
    private var formattedTimestamp: String {
        guard let timestamp = thought.timestamp else { return "Unviewed" }
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day, .month, .year], from: timestamp, to: now)
        
        if let years = components.year, years > 0 {
            return "Viewed \(years)y ago"
        }
        if let months = components.month, months > 0 {
            return "Viewed \(months)mo ago"
        }
        if let days = components.day, days > 0 {
            return "Viewed \(days)d ago"
        }
        if let hours = components.hour, hours > 0 {
            return "Viewed \(hours)h ago"
        }
        if let minutes = components.minute, minutes > 0 {
            return "Viewed \(minutes)m ago"
        }
        return "Viewed just now"
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                // Image preview section
                if !loadedImages.isEmpty && showPhotos {
                    // Show fixed grid of up to 4 images with +N counter for the 5th+ images
                    HStack(spacing: 8) {
                        ForEach(loadedImages.prefix(4).indices, id: \.self) { index in
                            Image(uiImage: loadedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if loadedImages.count > 4 {
                            Text("+\(loadedImages.count - 4)".localized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.colorNew.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(height: 60)
                    .padding()
                    .padding(.bottom, -20)
                }

                SimpleMarkdownText(
                    text: thought.content ?? "No Content",
                    lineLimit: showFullThought ? nil : 3
                )
                .padding()
                .frame(width: width, alignment: .leading)
                
                HStack {
                    // Bookmark moved to the left
                    Button(action: {
                            toggleFavorite()
                    }) {
                        Image(thought.favorite ? "bookmark-fill" : "bookmark")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Display tags from the tags string (comma-separated)
                    if let tagsString = thought.tags, !tagsString.isEmpty {
                        let tagNames = tagsString.components(separatedBy: ",")
                        
                        if showAllTags {
                            // Show all tags in a wrapped flow
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(tagNames, id: \.self) { tagName in
                                        if let tag = tagManager.getTagByName(tagName) {
                                            Text(tag.localizedName)
                                                .font(.caption)
                                                .lineLimit(1)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(tag.color.opacity(0.8))
                                                .foregroundColor(tag.color.isDark ? .white : .black)
                                                .cornerRadius(15)
                                        } else {
                                            Text(tagName)
                                                .font(.caption)
                                                .lineLimit(1)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.gray.opacity(0.3))
                                                .foregroundColor(.black)
                                                .cornerRadius(15)
                                        }
                                    }
                                }
                            }
                        } else {
                            // Show first tag with +N indicator
                            HStack(spacing: 4) {
                                if let firstTagName = tagNames.first, let firstTag = tagManager.getTagByName(firstTagName) {
                                    Text(firstTag.localizedName)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(firstTag.color.opacity(0.8))
                                        .foregroundColor(firstTag.color.isDark ? .white : .black)
                                        .cornerRadius(15)
                                    
                                    if tagNames.count > 1 {
                                        Text("+\(tagNames.count - 1)".localized)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.colorNew.opacity(0.9))
                                            .foregroundColor(.white)
                                            .cornerRadius(15)
                                    }
                                }
                            }
                        }
                    } else if let singleTag = thought.tag, !singleTag.isEmpty {
                        // Legacy single tag support
                        if let tag = tagManager.getTagByName(singleTag) {
                            Text(tag.localizedName)
                                .font(.caption)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tag.color.opacity(0.8))
                                .foregroundColor(tag.color.isDark ? .white : .black)
                                .cornerRadius(15)
                        } else {
                            Text(singleTag)
                                .font(.caption)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.black)
                                .cornerRadius(15)
                        }
                    } else {
                        Text("No tag".localized)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.black)
                            .cornerRadius(15)
                    }
                    
                    Spacer()
                    
                    if showTimestamps {
                        Text(formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.leading)
                .padding(.bottom, 10)
            }
            .cornerRadius(16)
            .fixedSize(horizontal: false, vertical: true)
            .rotationEffect(Angle(degrees: isWiggling && selectedForDeletion == thought ? -1 : 0))
            .animation(selectedForDeletion == thought ? wiggleAnimation : .default, value: isWiggling)
            .onTapGesture {
                onTap(thought)
            }
            .onLongPressGesture {
                withAnimation {
                    if selectedForDeletion == thought {
                        selectedForDeletion = nil
                        showDeleteButton = false
                    } else {
                        selectedForDeletion = thought
                        showDeleteButton = true
                        startTimer()
                    }
                }
            }
            .rotationEffect(selectedForDeletion == thought && showDeleteButton ? .degrees(2) : .degrees(0))
            .animation(
                selectedForDeletion == thought && showDeleteButton ?
                    Animation.linear(duration: 0.1).repeatForever(autoreverses: true) :
                    .default,
                value: selectedForDeletion == thought && showDeleteButton
            )

            if selectedForDeletion == thought && showDeleteButton {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image("trash")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(.red)
                        .padding([.top, .trailing], 5)
                }
            }
        }
        .background(
            ZStack {
                // Light mode background
                Color(UIColor.systemGray6)
                    .opacity(0.6)
                    .environment(\.colorScheme, .light)
                
                // Dark mode background
                Color(UIColor.systemGray5)
                    .opacity(0.4)
                    .environment(\.colorScheme, .dark)
            }
        )
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .onAppear {
            loadImages()
        }
        .onDisappear {
            isWiggling = false
        }
        .onChange(of: showDeleteButton) { oldValue, newValue in
            if !newValue {
                isWiggling = false
            }
        }
        .alert("Delete Thought".localized, isPresented: $showDeleteConfirmation) {
            Button("Cancel".localized, role: .cancel) { }
            Button("Delete".localized, role: .destructive) {
                onDelete(thought)
                withAnimation {
                    selectedForDeletion = nil
                    showDeleteButton = false
                }
            }
        } message: {
            Text("Are you sure you want to delete this thought? This action cannot be undone.".localized)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            withAnimation {
                showDeleteButton = false
                selectedForDeletion = nil
                isWiggling = false
            }
        }
    }
}

struct EmptyStateView: View {
    let message: String
    let createNewThought: () -> Void
    let tagManager: TagManager
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(message)
                .foregroundColor(.gray)
                .italic()
            
            Button(action: createNewThought) {
                Text("Create New Thought".localized)
                    .font(.system(size: 16))
                    .bold()
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 220)
                    .background(RoundedRectangle(cornerRadius: 10.0, style: .continuous).fill(Color.colorNew))
            }
            
            if !tagManager.selectedTags.isEmpty {
                Button(action: {
                    tagManager.clearTagSelection()
                }) {
                    Text("Clear Tag Filter\(tagManager.selectedTags.count > 1 ? "s" : "")")
                        .font(.system(size: 16))
                        .bold()
                        .foregroundColor(Color.colorPrimary)
                }
            }
            
            Spacer()
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.presentationMode) var presentationMode
    var shouldAppend: Bool = true // New property to control append behavior

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 0 // 0 means no limit
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss the picker
            parent.presentationMode.wrappedValue.dismiss()
            
            // Exit if no selection was made
            guard !results.isEmpty else { return }
            
            // Create a temporary array for new images
            var newImages: [UIImage] = []
            let group = DispatchGroup()
            
            // Process the selected images
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                        defer { group.leave() }
                        
                        if let error = error {
                            print("Error loading image: \(error.localizedDescription)")
                            return
                        }
                        
                        if let image = image as? UIImage {
                            newImages.append(image)
                        }
                    }
                }
            }
            
            // Update the parent binding when all images are loaded
            group.notify(queue: .main) {
                if self.parent.shouldAppend {
                    // Append new images to existing images
                    self.parent.images.append(contentsOf: newImages)
                    print("Added \(newImages.count) new images, total: \(self.parent.images.count)")
                } else {
                    // Replace existing images with new ones
                    self.parent.images = newImages
                    print("Replaced with \(newImages.count) new images")
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// First, add this custom divider view
struct CustomDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.colorPrimary.opacity(0.3))
            .frame(height: 1.5)
            .frame(maxWidth: .infinity)
    }
}

// Define the TagStat struct
struct TagStat: Identifiable {
    let id = UUID()
    let tagName: String
    let count: Int
    let tag: Tag?
    
    init(tagName: String, count: Int, tag: Tag?) {
        self.tagName = tagName.isEmpty ? "Untagged" : tagName
        self.count = count
        self.tag = tag
    }
}

