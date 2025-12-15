import Foundation
import SwiftUI

@MainActor
final class WeeklyObjectiveViewModel: ObservableObject {
    @Published var currentObjective: WeeklyObjective?
    @Published var historyObjectives: [WeeklyObjective] = []
    @Published var isLoading = false
    @Published var isCreating = false
    @Published var isGeneratingAI = false
    @Published var errorMessage: String?
    @Published var showCreateForm = false
    @Published var showHistory = false
    
    // Form fields
    @Published var formTitle = ""
    @Published var formTargetHours = 10
    @Published var formStartDate = Date()
    @Published var formEndDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @Published var formTasks: [String] = Array(repeating: "", count: 7)
    @Published var userGoalPrompt = ""  // User input for AI generation
    @Published var aiSuggestion = ""    // AI suggestion text
    
    private let service = WeeklyObjectiveService.shared
    private let authManager = AuthenticationManager.shared
    
    var hasActiveObjective: Bool {
        currentObjective != nil
    }
    
    // MARK: - Load Current Objective
    
    func loadCurrentObjective() async {
        guard let token = authManager.accessToken else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            currentObjective = try await service.getCurrentObjective(accessToken: token)
        } catch {
            // 404 is expected when no objective exists
            if (error as NSError).code != 404 {
                errorMessage = error.localizedDescription
            }
            currentObjective = nil
        }
        
        isLoading = false
    }
    
    // MARK: - Load History
    
    func loadHistory() async {
        guard let token = authManager.accessToken else { return }
        
        isLoading = true
        
        do {
            let response = try await service.getHistory(accessToken: token, page: 1, limit: 20)
            historyObjectives = response.objectives
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Create Objective
    
    func createObjective() async {
        guard let token = authManager.accessToken else { return }
        guard !formTitle.isEmpty else {
            errorMessage = "Please enter a title"
            return
        }
        
        // Validate tasks
        let nonEmptyTasks = formTasks.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard nonEmptyTasks.count == 7 else {
            errorMessage = "Please fill all 7 daily tasks"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        do {
            let objective = try await service.createObjective(
                accessToken: token,
                title: formTitle,
                targetHours: formTargetHours,
                startDate: formStartDate,
                endDate: formEndDate,
                tasks: formTasks
            )
            currentObjective = objective
            showCreateForm = false
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isCreating = false
    }
    
    // MARK: - Toggle Task Completion
    
    func toggleTask(at index: Int) async {
        guard let token = authManager.accessToken,
              let objective = currentObjective,
              index >= 0 && index < objective.dailyTasks.count else { return }
        
        let currentStatus = objective.dailyTasks[index].isCompleted
        
        // Optimistic update
        var updatedTasks = objective.dailyTasks
        updatedTasks[index].isCompleted = !currentStatus
        
        let completedCount = updatedTasks.filter { $0.isCompleted }.count
        let newCompletedHours = Double(completedCount) / 7.0 * Double(objective.targetHours)
        
        currentObjective = WeeklyObjective(
            id: objective.id,
            user: objective.user,
            title: objective.title,
            targetHours: objective.targetHours,
            completedHours: newCompletedHours,
            startDate: objective.startDate,
            endDate: objective.endDate,
            status: completedCount == 7 ? .completed : .inProgress,
            dailyTasks: updatedTasks,
            createdAt: objective.createdAt,
            updatedAt: Date()
        )
        
        do {
            let updated = try await service.updateTaskCompletion(
                accessToken: token,
                objectiveId: objective.id,
                taskIndex: index,
                isCompleted: !currentStatus
            )
            currentObjective = updated
        } catch {
            // Revert on error
            currentObjective = objective
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Delete Objective
    
    func deleteObjective() async {
        guard let token = authManager.accessToken,
              let objective = currentObjective else { return }
        
        do {
            try await service.deleteObjective(accessToken: token, objectiveId: objective.id)
            currentObjective = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helpers
    
    func resetForm() {
        formTitle = ""
        formTargetHours = 10
        formStartDate = Date()
        formEndDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
        formTasks = Array(repeating: "", count: 7)
        userGoalPrompt = ""
        aiSuggestion = ""
    }
    
    func presentCreateForm() {
        resetForm()
        showCreateForm = true
    }
    
    // MARK: - AI Generation
    
    func generateWithAI() async {
        guard !userGoalPrompt.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your learning goal"
            return
        }
        
        isGeneratingAI = true
        errorMessage = nil
        aiSuggestion = ""
        
        let systemPrompt = """
        You are a helpful assistant that creates weekly learning plans.
        Based on the user's goal, suggest a concise title and realistic hours.
        Provide a brief 1-sentence suggestion.
        Provide a daily breakdown for 7 days.
        Format your response EXACTLY like this (no markdown, no extra text):
        Title: [Title]
        Hours: [Number]
        Suggestion: [Text]
        Day 1: [Task description]
        Day 2: [Task description]
        Day 3: [Task description]
        Day 4: [Task description]
        Day 5: [Task description]
        Day 6: [Task description]
        Day 7: [Task description]
        """
        
        let fullPrompt = "\(systemPrompt)\n\nUser Goal: \(userGoalPrompt)"
        
        do {
            let response = try await callGeminiAPI(prompt: fullPrompt)
            parseAIResponse(response)
        } catch {
            errorMessage = "AI generation failed: \(error.localizedDescription)"
            // Set default placeholders on failure
            setDefaultTasks()
        }
        
        isGeneratingAI = false
    }
    
    private func callGeminiAPI(prompt: String) async throws -> String {
        // Use backend's Cloudflare AI endpoint
        guard let url = URL(string: "\(NetworkConfig.baseURL)/ai/chat") else {
            throw NSError(domain: "WeeklyObjective", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        // Add auth token if available
        if let token = await authManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let requestBody: [String: Any] = [
            "message": prompt
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🤖 [WeeklyObjective] Calling backend AI...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "WeeklyObjective", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorText = String(data: data, encoding: .utf8) {
                print("❌ [WeeklyObjective] API Error: \(httpResponse.statusCode) - \(errorText)")
            }
            throw NSError(domain: "WeeklyObjective", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API request failed with status \(httpResponse.statusCode)"])
        }
        
        // Parse backend response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw NSError(domain: "WeeklyObjective", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        print("✅ [WeeklyObjective] AI response received")
        return responseText
    }
    
    private func parseGeminiResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? String else {
            throw NSError(domain: "WeeklyObjective", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        return response
    }
    
    private func parseAIResponse(_ response: String) {
        let lines = response.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        
        var parsedTitle: String?
        var parsedHours: Int?
        var parsedSuggestion: String?
        var parsedTasks: [String] = []
        
        for line in lines {
            if line.hasPrefix("Title:") {
                parsedTitle = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Hours:") {
                let hoursStr = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                parsedHours = Int(hoursStr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 10
            } else if line.hasPrefix("Suggestion:") {
                parsedSuggestion = String(line.dropFirst(11)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Day ") {
                // Extract task after "Day X:"
                if let colonIndex = line.firstIndex(of: ":") {
                    let task = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    if !task.isEmpty {
                        parsedTasks.append(task)
                    }
                }
            }
        }
        
        // Apply parsed values or defaults
        if let title = parsedTitle, !title.isEmpty {
            formTitle = title
        }
        
        if let hours = parsedHours, hours > 0 && hours <= 50 {
            formTargetHours = hours
        }
        
        if let suggestion = parsedSuggestion, !suggestion.isEmpty {
            aiSuggestion = suggestion
        }
        
        // Fill tasks (ensure we have exactly 7)
        if parsedTasks.count >= 7 {
            formTasks = Array(parsedTasks.prefix(7))
        } else if !parsedTasks.isEmpty {
            // Pad with last task or generic tasks
            formTasks = parsedTasks
            while formTasks.count < 7 {
                formTasks.append("Continue learning - Day \(formTasks.count + 1)")
            }
        } else {
            setDefaultTasks()
        }
    }
    
    private func setDefaultTasks() {
        formTasks = [
            "Introduction and setup",
            "Learn fundamentals",
            "Practice basic concepts",
            "Work on exercises",
            "Build small project",
            "Review and refine",
            "Complete and summarize"
        ]
    }
}
