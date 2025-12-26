import SwiftUI
import CoreData
import UIKit
import StoreKit
import Charts // Import the Charts framework
import PhotosUI

struct AnalyticsView: View {
    let viewContext: NSManagedObjectContext
    @Environment(\.dismiss) var dismiss
    @State private var thoughts: [Thought] = []
    @State private var tagStats: [TagStat] = []
    @State private var selectedTimeRange: TimeRange = .allTime
    @State private var averageWordCount: Double = 0
    @State private var longestThought: (content: String, wordCount: Int) = ("", 0)
    @State private var mostProductiveHour: (hour: Int, count: Int) = (0, 0)
    @State private var currentStreak: Int = 0
    @State private var longestStreak: Int = 0
    @State private var animateCharts = false
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "Last 7 Days"
        case month = "Last 30 Days"
        case year = "Previous Year"
        case allTime = "All Time"
        
        var id: String { self.rawValue }
        
        var localizedTitle: String {
            switch self {
            case .week: return "Last 7 Days".localized
            case .month: return "Last 30 Days".localized
            case .year: return "Previous Year".localized
            case .allTime: return "All Time".localized
            }
        }
    }
    
    // Data structure for activity chart
    private struct ActivityData {
        let date: Date
        let count: Int
    }
    
    // Helper computed property for chart time unit
    private var chartTimeUnit: Calendar.Component {
        switch selectedTimeRange {
        case .week: return .day
        case .month: return .day
        case .year: return .month
        case .allTime: return .month
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range picker
                    timeRangePicker
                    
                    // Overview Cards
                    overviewCardsSection
                    
                    // Streak Section
                    streakSection
                    
                    // Additional Insights
                    insightsSection
                    
                    // Tags Section
                    tagsListSection
                }
                .padding(.top)
            }
            .navigationTitle("Analytics".localized)
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
        }
        .onAppear {
            loadData()
            // Remove delay and trigger animations immediately
            withAnimation {
                animateCharts = true
            }
        }
        .onDisappear {
            // Reset animation state
            animateCharts = false
        }
    }
    
    // MARK: - View Components
    
    private var timeRangePicker: some View {
        HStack {
            Text("Time Range".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Menu {
                ForEach(TimeRange.allCases) { range in
                    Button(action: {
                        selectedTimeRange = range
                        loadData()
                    }) {
                        Label {
                            Text(range.localizedTitle)
                        } icon: {
                            if range == selectedTimeRange {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedTimeRange.localizedTitle)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .foregroundColor(.primary)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private var overviewCardsSection: some View {
        VStack(spacing: 16) {
            // Thoughts and Daily Average
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Entries".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("\(thoughts.count)".localized)
                        .font(.title)
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Average Word Count".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f", averageWordCount))
                        .font(.title)
                        .bold()
                }
            }
            
            Divider()
            
            // Words and Characters
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Words".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("\(totalWords())".localized)
                        .font(.title)
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Total Characters".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("\(totalCharacters())".localized)
                        .font(.title)
                        .bold()
                }
            }
            
            mostActiveDaySection
        }
        .padding()
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.colorStroke, lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
    
    private var mostActiveDaySection: some View {
        let activeDay = mostActiveDay()
        
        return Group {
            if activeDay.count > 0 {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Most Active Day".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(String(format: "%lld entries on %@".localized, activeDay.count, activeDay.date.formatted(date: .abbreviated, time: .omitted)))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var activityChartSection: some View {
        VStack(alignment: .leading) {
            Text("Activity Over Time".localized)
                .font(.headline)
                .padding(.horizontal)
            
            let data = activityData(for: selectedTimeRange)
            
            Chart {
                ForEach(data.indices, id: \.self) { index in
                    let item = data[index]
                    BarMark(
                        x: .value("Date", item.date, unit: chartTimeUnit),
                        y: .value("Thoughts", animateCharts ? item.count : 0)
                    )
                    .foregroundStyle(Color.colorPrimary.gradient)
                }
            }
            .frame(height: 200)
            .padding()
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.colorStroke, lineWidth: 1.5)
            )
            .padding(.horizontal)
        }
    }
    
    private var tagsListSection: some View {
        VStack(alignment: .leading) {
            Text("All Tags".localized)
                .font(.headline)
                .padding(.horizontal)
            
            if tagStats.isEmpty {
                Text("No tags used yet".localized)
                    .foregroundColor(.gray)
                    .italic()
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Remove the ScrollView and just use a regular VStack
                VStack(spacing: 12) {
                    ForEach(tagStats.sorted(by: { $0.count > $1.count })) { stat in
                        tagRow(for: stat)
                    }
                }
                .padding(.top, 8)
            }
        }
        // Remove the fixed height constraint that was limiting the ScrollView
    }
    
    private func tagRow(for stat: TagStat) -> some View {
        HStack {
            if let tag = stat.tag {
                Text(tag.localizedName)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(tag.color.opacity(0.8))
                    .foregroundColor(tag.color.isDark ? .white : .black)
                    .cornerRadius(40)
            } else {
                Text(stat.tagName)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(40)
            }
            
            Spacer()
            
            Text("\(stat.count)".localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.colorStroke, lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights".localized)
                .font(.headline)
                .padding(.horizontal)
            
            // Average Word Count
            InsightCard(
                title: "Average Words per Entry".localized,
                value: String(format: "%.1f", averageWordCount),
                icon: "notes"
            )
            
            // Most Productive Hour
            InsightCard(
                title: "Most Productive at".localized,
                value: String(format: "%@ (%lld entries)".localized, formatHour(mostProductiveHour.hour), mostProductiveHour.count),
                icon: "clock"
            )
            
            // Longest Thought
            longestThoughtSection
        }

    }
    
    private var longestThoughtSection: some View {
        Group {
            if !longestThought.content.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.quote")
                            .foregroundColor(Color.colorPrimary)
                        Text("Longest Entry".localized)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(longestThought.wordCount) words".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    ScrollView {
                        Text(longestThought.content)
                            .font(.body)
                            .padding(.top, 4)
                    }
                    .frame(maxHeight: 300)
                }
                .padding()
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.colorStroke, lineWidth: 1.5)
                )
                .padding(.horizontal)
            }
        }
    }
    
    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Writing Streaks".localized)
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(currentStreak)".localized)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color.colorPrimary)
                    Text("Current".localized)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("\(longestStreak)".localized)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color.colorPrimary)
                    Text("Longest".localized)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.colorStroke, lineWidth: 1.5)
            )
            .padding(.horizontal)
        }
    }
    
    // MARK: - Data Methods
    
    // Generate activity data based on time range
    private func activityData(for timeRange: TimeRange) -> [ActivityData] {
        let calendar = Calendar.current
        let now = Date()
        var startDate: Date
        var endDate = now
        
        switch timeRange {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: now)!
        case .year:
            // Get previous year (Jan 1 to Dec 31)
            var previousYearComponents = calendar.dateComponents([.year], from: now)
            previousYearComponents.year! -= 1
            previousYearComponents.month = 1
            previousYearComponents.day = 1
            startDate = calendar.date(from: previousYearComponents)!
            
            previousYearComponents.month = 12
            previousYearComponents.day = 31
            endDate = calendar.date(from: previousYearComponents)!
        case .allTime:
            if let oldest = thoughts.map({ $0.creationDate ?? Date() }).min() {
                startDate = oldest
            } else {
                startDate = calendar.date(byAdding: .year, value: -1, to: now)!
            }
        }
        
        // Group thoughts by date
        let filteredThoughts = thoughts.filter { thought in
            guard let date = thought.creationDate else { return false }
            return date >= startDate && date <= endDate
        }
        
        let groupedByDate = Dictionary(grouping: filteredThoughts) { thought in
            let date = thought.creationDate ?? Date()
            switch timeRange {
            case .week, .month:
                return calendar.startOfDay(for: date)
            case .year, .allTime:
                let components = calendar.dateComponents([.year, .month], from: date)
                return calendar.date(from: components)!
            }
        }
        
        // Create date range
        var dateRange: [Date] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            dateRange.append(currentDate)
            switch timeRange {
            case .week, .month:
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            case .year, .allTime:
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
            }
        }
        
        // Map to activity data
        return dateRange.map { date in
            ActivityData(
                date: date,
                count: groupedByDate[date]?.count ?? 0
            )
        }
    }
    
    private func calculateTagStats() {
        // Get all existing tag names from both default and custom tags
        var allTagNames = Set<String>()
        var tagLookup = [String: Tag]()
        
        // Add all default tags
        for tag in Tag.defaultTags {
            allTagNames.insert(tag.name)
            tagLookup[tag.name] = tag
        }
        
        // Add all custom tags from the tag manager
        let tagManager = TagManager(viewContext: viewContext)
        for tag in tagManager.customTags {
            allTagNames.insert(tag.name)
            tagLookup[tag.name] = tag
        }
        
        // Count thoughts per tag
        var tagCounts = [String: Int]()
        
        // Look for tags in both the legacy 'tag' field and the new 'tags' field
        for thought in thoughts {
            // Process legacy single tag
            if let tagName = thought.tag, !tagName.isEmpty {
                tagCounts[tagName, default: 0] += 1
            }
            
            // Process multiple tags if available
            if let tagsString = thought.tags, !tagsString.isEmpty {
                let tagNames = tagsString.components(separatedBy: ",")
                for tagName in tagNames {
                    if !tagName.isEmpty {
                        tagCounts[tagName, default: 0] += 1
                    }
                }
            }
        }
        
        // Convert to TagStat objects
        var stats: [TagStat] = []
        
        // First add stats for tags that have been used
        for (tagName, count) in tagCounts {
            // Skip empty tags
            if tagName.isEmpty {
                continue
            }
            
            // Look up the tag object if available
            let tag = tagLookup[tagName]
            stats.append(TagStat(tagName: tagName, count: count, tag: tag))
        }
        
        // Then add any tags that haven't been used but exist in the system
        for tagName in allTagNames {
            if !tagCounts.keys.contains(tagName) {
                stats.append(TagStat(tagName: tagName, count: 0, tag: tagLookup[tagName]))
            }
        }
        
        tagStats = stats
    }
    
    private func loadData() {
        let request: NSFetchRequest<Thought> = Thought.fetchRequest()
        
        // Add time range filter if needed
        if selectedTimeRange != .allTime {
            let calendar = Calendar.current
            let now = Date()
            var startDate: Date
            var endDate = now
            
            switch selectedTimeRange {
            case .week:
                startDate = calendar.date(byAdding: .day, value: -7, to: now)!
            case .month:
                startDate = calendar.date(byAdding: .day, value: -30, to: now)!
            case .year:
                // Get previous year (Jan 1 to Dec 31)
                var previousYearComponents = calendar.dateComponents([.year], from: now)
                previousYearComponents.year! -= 1
                previousYearComponents.month = 1
                previousYearComponents.day = 1
                startDate = calendar.date(from: previousYearComponents)!
                
                previousYearComponents.month = 12
                previousYearComponents.day = 31
                endDate = calendar.date(from: previousYearComponents)!
                
                request.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", startDate as NSDate, endDate as NSDate)
            default:
                startDate = Date.distantPast
                request.predicate = NSPredicate(format: "creationDate >= %@", startDate as NSDate)
            }
            
            if selectedTimeRange != .year {
                request.predicate = NSPredicate(format: "creationDate >= %@", startDate as NSDate)
            }
        }
        
        do {
            thoughts = try viewContext.fetch(request)
            calculateTagStats()
            calculateAdditionalMetrics()
            calculateStreaks()
        } catch {
            print("Error fetching thoughts: \(error)")
        }
    }
    
    private func calculateAdditionalMetrics() {
        // Calculate average word count
        let totalWords = thoughts.reduce(0) { sum, thought in
            sum + (thought.content?.split(separator: " ").count ?? 0)
        }
        averageWordCount = thoughts.isEmpty ? 0 : Double(totalWords) / Double(thoughts.count)
        
        // Find longest thought
        if let longest = thoughts.max(by: {
            ($0.content?.split(separator: " ").count ?? 0) <
            ($1.content?.split(separator: " ").count ?? 0)
        }) {
            let wordCount = longest.content?.split(separator: " ").count ?? 0
            longestThought = (longest.content ?? "", wordCount)
        }
        
        // Find most productive hour
        let hourCounts = Dictionary(grouping: thoughts) { thought in
            Calendar.current.component(.hour, from: thought.creationDate ?? Date())
        }.mapValues { $0.count }
        
        if let mostActive = hourCounts.max(by: { $0.value < $1.value }) {
            mostProductiveHour = (mostActive.key, mostActive.value)
        }
    }
    
    private func calculateStreaks() {
        let calendar = Calendar.current
        
        // Get all dates with thoughts
        let thoughtDates = thoughts.compactMap { thought -> Date? in
            guard let date = thought.creationDate else { return nil }
            return calendar.startOfDay(for: date)
        }
        
        // Sort dates and remove duplicates
        let uniqueDates = Array(Set(thoughtDates)).sorted()
        
        // Calculate current streak
        currentStreak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        while uniqueDates.contains(currentDate) {
            currentStreak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        // Calculate longest streak
        longestStreak = 0
        var tempStreak = 0
        
        for i in 0..<uniqueDates.count {
            if i == 0 {
                tempStreak = 1
                continue
            }
            
            let previousDate = uniqueDates[i-1]
            let currentDate = uniqueDates[i]
            
            let daysBetween = calendar.dateComponents([.day], from: previousDate, to: currentDate).day ?? 0
            
            if daysBetween == 1 {
                tempStreak += 1
            } else {
                longestStreak = max(longestStreak, tempStreak)
                tempStreak = 1
            }
        }
        
        longestStreak = max(longestStreak, tempStreak)
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
    
    private func totalWords() -> Int {
        thoughts.reduce(0) { sum, thought in
            sum + (thought.content?.split(separator: " ").count ?? 0)
        }
    }
    
    private func totalCharacters() -> Int {
        thoughts.reduce(0) { sum, thought in
            sum + (thought.content?.count ?? 0)
        }
    }
    
    private func mostActiveDay() -> (date: Date, count: Int) {
        let calendar = Calendar.current
        
        // Create a dictionary to count thoughts per day
        var dayCountMap: [Date: Int] = [:]
        
        // Count thoughts for each day based on creation date
        for thought in thoughts {
            if let creationDate = thought.creationDate {
                let startOfDay = calendar.startOfDay(for: creationDate)
                dayCountMap[startOfDay, default: 0] += 1
            }
        }
        
        // Find the day with the most thoughts
        if let mostActiveDay = dayCountMap.max(by: { $0.value < $1.value }) {
            return (mostActiveDay.key, mostActiveDay.value)
        }
        
        return (Date(), 0)
    }
}

// Helper view for insights
struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(Color.colorPrimary)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.headline)
        }
        .padding()
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.colorStroke, lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
}
