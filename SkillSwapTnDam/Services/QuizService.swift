import Foundation

struct QuizQuestion: Codable, Identifiable {
    let id = UUID()
    let question: String
    let options: [String]
    let correctAnswerIndex: Int
    let explanation: String?
    
    enum CodingKeys: String, CodingKey {
        case question, options, correctAnswerIndex = "correctAnswer", explanation
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        question = try container.decode(String.self, forKey: .question)
        options = try container.decode([String].self, forKey: .options)
        correctAnswerIndex = try container.decode(Int.self, forKey: .correctAnswerIndex)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
    }
}

struct QuizResult: Codable, Identifiable {
    let id: String
    let skill: String
    let level: Int
    let score: Int
    let totalQuestions: Int
    let percentage: Int?
    let completedAt: Date?
    
    // For local use when creating a result
    var date: Date {
        completedAt ?? Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "_id", skill, level, score, totalQuestions, percentage, completedAt
    }
    
    init(id: String, skill: String, level: Int, score: Int, totalQuestions: Int, percentage: Int? = nil, completedAt: Date? = nil) {
        self.id = id
        self.skill = skill
        self.level = level
        self.score = score
        self.totalQuestions = totalQuestions
        self.percentage = percentage
        self.completedAt = completedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Handle both "id" and "_id" from backend
        if let idValue = try? container.decode(String.self, forKey: .id) {
            id = idValue
        } else {
            id = UUID().uuidString
        }
        skill = try container.decode(String.self, forKey: .skill)
        level = try container.decode(Int.self, forKey: .level)
        score = try container.decode(Int.self, forKey: .score)
        totalQuestions = try container.decode(Int.self, forKey: .totalQuestions)
        percentage = try container.decodeIfPresent(Int.self, forKey: .percentage)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

class QuizService {
    static let shared = QuizService()
    
    private var baseURL: String {
        NetworkConfig.baseURL
    }
    
    // MARK: - Cache for offline fallback
    private let historyKey = "quiz_history_cache"
    private let progressKey = "quiz_progress_cache"
    
    func generateQuiz(subject: String, level: Int) async throws -> [QuizQuestion] {
        // Convert level number to string (beginner/intermediate/advanced)
        let levelString: String
        switch level {
        case 1...3: levelString = "beginner"
        case 4...6: levelString = "intermediate"
        case 7...10: levelString = "advanced"
        default: levelString = "beginner"
        }
        
        guard let url = URL(string: "\(baseURL)/quizzes/generate") else {
            throw NSError(domain: "QuizService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = await AuthenticationManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "skill": subject,
            "level": levelString,
            "numberOfQuestions": 5
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "QuizService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode == 401 {
            throw NSError(domain: "QuizService", code: 401, 
                         userInfo: [NSLocalizedDescriptionKey: "Please login to generate quizzes"])
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("Quiz API Error: \(errorString)")
            }
            throw NSError(domain: "QuizService", code: httpResponse.statusCode, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to generate quiz (HTTP \(httpResponse.statusCode))"])
        }
        
        // Parse backend response
        struct BackendQuizResponse: Decodable {
            let skill: String
            let level: String
            let totalQuestions: Int
            let questions: [QuizQuestion]
        }
        
        let quizResponse = try JSONDecoder().decode(BackendQuizResponse.self, from: data)
        return quizResponse.questions
    }
    
    // MARK: - Backend Result Management
    
    func saveResult(_ result: QuizResult) async throws {
        guard let url = URL(string: "\(baseURL)/quizzes/results") else {
            throw NSError(domain: "QuizService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        guard let token = await AuthenticationManager.shared.accessToken else {
            throw NSError(domain: "QuizService", code: 401,
                         userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "skill": result.skill,
            "level": result.level,
            "score": result.score,
            "totalQuestions": result.totalQuestions,
            "answers": []
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("📤 [QuizService] Saving result to backend: \(result.skill) level \(result.level)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [QuizService] Failed to save result: \(errorText)")
            throw NSError(domain: "QuizService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to save result"])
        }
        
        print("✅ [QuizService] Result saved to backend")
        
        // Also cache locally for offline access
        cacheResult(result)
    }
    
    func getHistory() async throws -> [QuizResult] {
        guard let url = URL(string: "\(baseURL)/quizzes/results") else {
            return getCachedHistory()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        guard let token = await AuthenticationManager.shared.accessToken else {
            return getCachedHistory()
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return getCachedHistory()
            }
            
            struct HistoryResponse: Decodable {
                let results: [QuizResult]
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let historyResponse = try decoder.decode(HistoryResponse.self, from: data)
            
            // Cache for offline use
            if let encoded = try? JSONEncoder().encode(historyResponse.results) {
                UserDefaults.standard.set(encoded, forKey: historyKey)
            }
            
            return historyResponse.results
        } catch {
            print("❌ [QuizService] Failed to fetch history: \(error)")
            return getCachedHistory()
        }
    }
    
    func getUnlockedLevel(for subject: String) async -> Int {
        guard let url = URL(string: "\(baseURL)/quizzes/results/\(subject.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? subject)") else {
            return getCachedUnlockedLevel(for: subject)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        guard let token = await AuthenticationManager.shared.accessToken else {
            return getCachedUnlockedLevel(for: subject)
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return getCachedUnlockedLevel(for: subject)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let results = try decoder.decode([QuizResult].self, from: data)
            
            // Calculate max unlocked level: highest passed level + 1
            var maxLevel = 1
            for result in results {
                let passed = (Double(result.score) / Double(result.totalQuestions)) >= 0.5
                if passed && result.level >= maxLevel {
                    maxLevel = min(result.level + 1, 10)
                }
            }
            
            // Cache the result
            var progress = UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int] ?? [:]
            progress[subject] = maxLevel
            UserDefaults.standard.set(progress, forKey: progressKey)
            
            return maxLevel
        } catch {
            print("❌ [QuizService] Failed to get skill progress: \(error)")
            return getCachedUnlockedLevel(for: subject)
        }
    }
    
    // MARK: - Sync version for compatibility
    
    func getUnlockedLevel(for subject: String) -> Int {
        getCachedUnlockedLevel(for: subject)
    }
    
    func saveResult(_ result: QuizResult) {
        // Fire and forget async save
        Task {
            do {
                try await saveResult(result)
            } catch {
                print("❌ [QuizService] Background save failed: \(error)")
            }
        }
        // Always cache locally immediately
        cacheResult(result)
    }
    
    func getHistory() -> [QuizResult] {
        getCachedHistory()
    }
    
    // MARK: - Local Cache Helpers
    
    private func cacheResult(_ result: QuizResult) {
        var history = getCachedHistory()
        history.insert(result, at: 0)
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
        
        // Update progress cache if passed
        if Double(result.score) / Double(result.totalQuestions) >= 0.5 {
            var progress = UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int] ?? [:]
            let maxLevel = progress[result.skill] ?? 1
            if result.level >= maxLevel && maxLevel < 10 {
                progress[result.skill] = result.level + 1
                UserDefaults.standard.set(progress, forKey: progressKey)
            }
        }
    }
    
    private func getCachedHistory() -> [QuizResult] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([QuizResult].self, from: data) else {
            return []
        }
        return history
    }
    
    private func getCachedUnlockedLevel(for subject: String) -> Int {
        let progress = UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int] ?? [:]
        return progress[subject] ?? 1
    }
}
