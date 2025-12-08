import Foundation

struct Session: Identifiable, Codable {
    let id: String
    let teacher: SessionUserSummary?
    let student: SessionUserSummary?
    let students: [SessionUserSummary]?
    let skill: String
    let title: String
    let date: Date
    let duration: Int
    let status: String
    let meetingLink: String?
    let location: String?
    let notes: String?
    let feedbackGiven: Bool?
    let teacherRating: Int?
    let studentRating: Int?
    let rescheduleRequest: RescheduleStatus?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case teacher, student, students, skill, title, date, duration, status, meetingLink, location, notes, feedbackGiven, teacherRating, studentRating, rescheduleRequest
    }
    
    // Safe accessor for teacher - returns a default if nil
    var safeTeacher: SessionUserSummary {
        teacher ?? SessionUserSummary(id: "", username: "Utilisateur inconnu", email: "", image: nil, avatarUrl: nil)
    }
}

struct SessionUserSummary: Codable, Identifiable {
    let id: String
    let username: String
    let email: String
    let image: String?
    let avatarUrl: String?

    var displayImage: String? {
        avatarUrl ?? image
    }

    var initials: String {
        let components = username.split(separator: " ")
        let initials = components.prefix(2).map { String($0.prefix(1)) }.joined()
        return initials.isEmpty ? String(username.prefix(2)) : initials
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username, email, image, avatarUrl
    }
    
    init(id: String, username: String, email: String, image: String?, avatarUrl: String?) {
        self.id = id
        self.username = username
        self.email = email
        self.image = image
        self.avatarUrl = avatarUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
    }
}

typealias Teacher = SessionUserSummary
typealias Student = SessionUserSummary

struct RescheduleVote: Codable, Identifiable {
    let userId: String
    let answer: String
    let respondedAt: Date?

    var id: String { userId }
}

struct RescheduleStatus: Codable {
    let proposedDate: Date?
    let proposedTime: String?
    let note: String?
    let responses: [RescheduleVote]?
    let isActive: Bool?
    
    var totalVotes: Int {
        responses?.count ?? 0
    }
    
    var yesVotes: Int {
        responses?.filter { $0.answer == "yes" }.count ?? 0
    }
    
    var isApproved: Bool {
        guard totalVotes > 0 else { return false }
        let approvalRate = Double(yesVotes) / Double(totalVotes)
        return approvalRate >= 0.66
    }
}

enum RescheduleDecision: String {
    case yes
    case no
}

struct BusyInterval: Codable, Identifiable {
    let startTime: String
    let endTime: String
    let title: String?
    let status: String?

    var id: String { "\(startTime)-\(endTime)" }
}

struct ConflictInfo: Codable {
    let title: String?
    let date: String?
    let duration: Int?
}

// Used for decoding the backend check-availability response
struct AvailabilityCheckResult: Codable {
    let isAvailable: Bool
    let conflictingSessions: [ConflictInfo]?
}

struct AvailabilityResponse: Codable {
    let user: SessionUserSummary
    let isAvailable: Bool
    let conflict: ConflictInfo?
    let conflictingSessions: [ConflictInfo]?
    
    init(user: SessionUserSummary, isAvailable: Bool, conflict: ConflictInfo? = nil, conflictingSessions: [ConflictInfo]? = nil) {
        self.user = user
        self.isAvailable = isAvailable
        self.conflict = conflict
        self.conflictingSessions = conflictingSessions
    }
}

struct SessionsResponse: Decodable {
    let message: String?
    let data: [Session]
}

struct SessionResponse: Decodable {
    let message: String?
    let data: Session
}

struct ApiResponse<T: Codable>: Codable {
    let message: String?
    let data: T?
    let error: String?
}

// Backend availability response format
struct BackendAvailabilityResponse: Codable {
    let data: [BackendAvailabilityItem]
}

struct BackendAvailabilityItem: Codable {
    let user: BackendAvailabilityUser
    let available: Bool
    let message: String
    let conflictingSession: BackendConflictSession?
}

struct BackendAvailabilityUser: Codable {
    let id: String
    let username: String
    let email: String
    let image: String?
}

struct BackendConflictSession: Codable {
    let title: String
    let date: String
}

struct NewSession: Codable {
    let title: String
    let skill: String
    let date: String
    let duration: Int
    let status: String
    let meetingLink: String?
    let location: String?
    let notes: String?
    let studentEmail: String?
    let studentEmails: [String]?
    
    init(title: String, skill: String, date: String, duration: Int, status: String, meetingLink: String? = nil, location: String? = nil, notes: String? = nil, studentEmail: String? = nil, studentEmails: [String]? = nil) {
        self.title = title
        self.skill = skill
        self.date = date
        self.duration = duration
        self.status = status
        self.meetingLink = meetingLink
        self.location = location
        self.notes = notes
        self.studentEmail = studentEmail
        self.studentEmails = studentEmails
    }
}

// MARK: - String Status Extension for compatibility
extension String {
    var allowsReschedule: Bool {
        self == "upcoming" || self == "postponed" || self == "reportee"
    }
}

// MARK: - SessionStatus enum for backward compatibility
enum SessionStatus: String, CaseIterable {
    case upcoming
    case completed
    case cancelled
    case postponed
    
    var allowsReschedule: Bool {
        self == .upcoming || self == .postponed
    }
}

// MARK: - Session extensions for compatibility
extension Session {
    var mentorName: String {
        safeTeacher.username
    }
    
    var learnerName: String {
        student?.username ?? "Participant"
    }
    
    var scheduledDate: Date? {
        date
    }
    
    var statusLabel: String {
        switch status {
        case "upcoming": return "À venir"
        case "completed": return "Terminée"
        case "cancelled": return "Annulée"
        case "postponed", "reportee": return "Reportée"
        default: return status.capitalized
        }
    }

    var statusColor: String {
        switch status {
        case "upcoming": return "#2563EB"
        case "completed": return "#059669"
        case "cancelled": return "#DC2626"
        case "postponed", "reportee": return "#D97706"
        default: return "#6B7280"
        }
    }

    var formattedSchedule: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
    }

    var shortTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    var durationText: String {
        "\(duration) min"
    }
}
