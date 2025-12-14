import WidgetKit
import SwiftUI

// MARK: - Widget Entry
struct WeeklyObjectiveEntry: TimelineEntry {
    let date: Date
    let objective: WidgetObjective?
    let configuration: ConfigurationAppIntent
}

struct WidgetObjective {
    let id: String
    let title: String
    let targetHours: Int
    let completedHours: Double
    let todayTask: String
    let todayTaskCompleted: Bool
    let completedTasksCount: Int
    let totalTasks: Int
    
    var progressPercent: Int {
        guard targetHours > 0 else { return 0 }
        return min(100, Int((completedHours / Double(targetHours)) * 100))
    }
}

// MARK: - Configuration Intent
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Weekly Objective"
    static var description: IntentDescription = IntentDescription("Shows your current weekly objective progress")
}

// MARK: - Timeline Provider
struct WeeklyObjectiveProvider: AppIntentTimelineProvider {
    
    func placeholder(in context: Context) -> WeeklyObjectiveEntry {
        WeeklyObjectiveEntry(
            date: Date(),
            objective: WidgetObjective(
                id: "placeholder",
                title: "Learn Swift",
                targetHours: 10,
                completedHours: 4.5,
                todayTask: "Complete chapter 5",
                todayTaskCompleted: false,
                completedTasksCount: 3,
                totalTasks: 7
            ),
            configuration: ConfigurationAppIntent()
        )
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> WeeklyObjectiveEntry {
        let objective = await fetchCurrentObjective()
        return WeeklyObjectiveEntry(date: Date(), objective: objective, configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<WeeklyObjectiveEntry> {
        let objective = await fetchCurrentObjective()
        let entry = WeeklyObjectiveEntry(date: Date(), objective: objective, configuration: configuration)
        
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func fetchCurrentObjective() async -> WidgetObjective? {
        // Try to get token from shared App Group UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.skillswaptn.app")
        guard let token = sharedDefaults?.string(forKey: "accessToken") else {
            return nil
        }
        
        let baseURL = sharedDefaults?.string(forKey: "baseURL") ?? "https://l06wdxq5-3000.uks1.devtunnels.ms"
        
        guard let url = URL(string: "\(baseURL)/weekly-objectives/current") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let objective = try decoder.decode(WeeklyObjectiveResponse.self, from: data)
            
            // Calculate today's task
            let todayIndex = calculateTodayIndex(startDate: objective.startDate)
            let todayTask = todayIndex < objective.dailyTasks.count ? objective.dailyTasks[todayIndex] : nil
            
            return WidgetObjective(
                id: objective.id,
                title: objective.title,
                targetHours: objective.targetHours,
                completedHours: objective.completedHours,
                todayTask: todayTask?.task ?? "No task for today",
                todayTaskCompleted: todayTask?.isCompleted ?? false,
                completedTasksCount: objective.dailyTasks.filter { $0.isCompleted }.count,
                totalTasks: objective.dailyTasks.count
            )
        } catch {
            print("Widget fetch error: \(error)")
            return nil
        }
    }
    
    private func calculateTodayIndex(startDate: Date) -> Int {
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(0, min(6, daysSinceStart))
    }
}

// MARK: - API Response Models
struct WeeklyObjectiveResponse: Decodable {
    let id: String
    let title: String
    let targetHours: Int
    let completedHours: Double
    let startDate: Date
    let endDate: Date
    let status: String
    let dailyTasks: [DailyTaskResponse]
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case targetHours
        case completedHours
        case startDate
        case endDate
        case status
        case dailyTasks
    }
}

struct DailyTaskResponse: Decodable {
    let day: String
    let task: String
    let isCompleted: Bool
}

// MARK: - Widget View
struct WeeklyObjectiveWidgetEntryView: View {
    var entry: WeeklyObjectiveProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if let objective = entry.objective {
            objectiveView(objective)
        } else {
            emptyView
        }
    }
    
    private func objectiveView(_ objective: WidgetObjective) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("🎯 Weekly Objective")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Title
            Text(objective.title)
                .font(.headline)
                .lineLimit(1)
            
            // Today's task
            HStack(spacing: 4) {
                Image(systemName: objective.todayTaskCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundColor(objective.todayTaskCompleted ? .green : .orange)
                Text(objective.todayTask)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(objective.todayTaskCompleted ? .secondary : .primary)
                    .strikethrough(objective.todayTaskCompleted)
            }
            
            Spacer()
            
            // Stats
            HStack {
                Text(String(format: "%.1fh / %dh", objective.completedHours, objective.targetHours))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(objective.completedTasksCount)/\(objective.totalTasks) tasks")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(objective.progressPercent) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "target")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("No Active Objective")
                .font(.headline)
            
            Text("Tap to create one")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Widget Configuration
struct WeeklyObjectiveWidget: Widget {
    let kind: String = "WeeklyObjectiveWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: WeeklyObjectiveProvider()
        ) { entry in
            WeeklyObjectiveWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weekly Objective")
        .description("Track your weekly learning objective progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle
@main
struct WeeklyObjectiveWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeeklyObjectiveWidget()
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    WeeklyObjectiveWidget()
} timeline: {
    WeeklyObjectiveEntry(
        date: Date(),
        objective: WidgetObjective(
            id: "1",
            title: "Learn Swift",
            targetHours: 10,
            completedHours: 4.5,
            todayTask: "Complete chapter 5",
            todayTaskCompleted: false,
            completedTasksCount: 3,
            totalTasks: 7
        ),
        configuration: ConfigurationAppIntent()
    )
    
    WeeklyObjectiveEntry(
        date: Date(),
        objective: nil,
        configuration: ConfigurationAppIntent()
    )
}
