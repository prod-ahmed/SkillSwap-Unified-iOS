import Foundation

// MARK: - Weekly Objective Models

struct WeeklyObjective: Codable, Identifiable {
    let id: String
    let user: String
    let title: String
    let targetHours: Int
    let completedHours: Double
    let startDate: Date
    let endDate: Date
    let status: ObjectiveStatus
    let dailyTasks: [DailyTask]
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case user
        case title
        case targetHours
        case completedHours
        case startDate
        case endDate
        case status
        case dailyTasks
        case createdAt
        case updatedAt
    }
    
    var progressPercent: Int {
        guard targetHours > 0 else { return 0 }
        return min(100, Int((completedHours / Double(targetHours)) * 100))
    }
    
    var completedTasksCount: Int {
        dailyTasks.filter { $0.isCompleted }.count
    }
    
    var todayTaskIndex: Int {
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(0, min(6, daysSinceStart))
    }
    
    var todayTask: DailyTask? {
        let index = todayTaskIndex
        guard index >= 0 && index < dailyTasks.count else { return nil }
        return dailyTasks[index]
    }
}

enum ObjectiveStatus: String, Codable {
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
}

struct DailyTask: Codable, Identifiable {
    var id: String { day }
    let day: String
    let task: String
    var isCompleted: Bool
}

// MARK: - DTOs for API

struct CreateWeeklyObjectiveRequest: Encodable {
    let title: String
    let targetHours: Int
    let startDate: String
    let endDate: String
    let dailyTasks: [DailyTaskRequest]
}

struct DailyTaskRequest: Encodable {
    let day: String
    let task: String
}

struct UpdateWeeklyObjectiveRequest: Encodable {
    let taskUpdates: [TaskUpdateRequest]
}

struct TaskUpdateRequest: Encodable {
    let index: Int
    let isCompleted: Bool
}

struct WeeklyObjectiveHistoryResponse: Decodable {
    let objectives: [WeeklyObjective]
    let total: Int
    let page: Int
    let pages: Int
}
