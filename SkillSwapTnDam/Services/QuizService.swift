import Foundation

struct QuizQuestion: Codable, Identifiable {
    let id = UUID()
    let question: String
    let options: [String]
    let correctAnswerIndex: Int
    let explanation: String
    
    enum CodingKeys: String, CodingKey {
        case question, options, correctAnswerIndex, explanation
    }
}

struct QuizResult: Codable, Identifiable {
    let id: String
    let subject: String
    let level: Int
    let score: Int
    let totalQuestions: Int
    let date: Date
}

class QuizService {
    static let shared = QuizService()
    
    // ⚠️ PUT YOUR OPENAI API KEY HERE
    private let apiKey = ""
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    func generateQuiz(subject: String, level: Int) async throws -> [QuizQuestion] {
        let prompt = """
        Generate a quiz about "\(subject)" for level \(level) (where 1 is beginner and 10 is expert).
        Create 5 multiple choice questions.
        Return ONLY a JSON array of objects with this structure:
        [
            {
                "question": "Question text",
                "options": ["Option A", "Option B", "Option C", "Option D"],
                "correctAnswerIndex": 0, // 0-3
                "explanation": "Brief explanation of the correct answer"
            }
        ]
        Do not include markdown formatting like ```json.
        """
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful quiz generator."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("OpenAI Error: \(errorJson)")
            }
            throw NSError(domain: "QuizService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate quiz"])
        }
        
        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = apiResponse.choices.first?.message.content else {
            throw NSError(domain: "QuizService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No content in response"])
        }
        
        // Clean up markdown if present
        let cleanContent = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
             throw NSError(domain: "QuizService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process content"])
        }
        
        return try JSONDecoder().decode([QuizQuestion].self, from: jsonData)
    }
    
    // MARK: - History Management (Local Persistence)
    
    private let historyKey = "quiz_history"
    private let progressKey = "quiz_progress" // Map of Subject -> Max Level Unlocked
    
    func saveResult(_ result: QuizResult) {
        var history = getHistory()
        history.append(result)
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
        
        // Update progress if passed (e.g. > 50%)
        if Double(result.score) / Double(result.totalQuestions) >= 0.5 {
            unlockNextLevel(subject: result.subject, currentLevel: result.level)
        }
    }
    
    func getHistory() -> [QuizResult] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([QuizResult].self, from: data) else {
            return []
        }
        return history.sorted(by: { $0.date > $1.date })
    }
    
    func getUnlockedLevel(for subject: String) -> Int {
        let progress = UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int] ?? [:]
        return progress[subject] ?? 1
    }
    
    private func unlockNextLevel(subject: String, currentLevel: Int) {
        var progress = UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int] ?? [:]
        let maxLevel = progress[subject] ?? 1
        if currentLevel >= maxLevel && maxLevel < 10 {
            progress[subject] = currentLevel + 1
            UserDefaults.standard.set(progress, forKey: progressKey)
        }
    }
}
