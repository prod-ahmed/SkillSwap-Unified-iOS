import SwiftUI

struct QuizzesView: View {
    @AppStorage("quiz_last_subject") private var subject: String = ""
    @State private var isEditingSubject = true
    @State private var showHistory = false
    @StateObject private var service = QuizServiceWrapper()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("AI Quiz Roadmap")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    if isEditingSubject {
                        HStack {
                            TextField("Enter a subject (e.g. Swift, History)", text: $subject)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(.black)
                            
                            Button("Start") {
                                if !subject.isEmpty {
                                    withAnimation {
                                        isEditingSubject = false
                                        service.loadProgress(for: subject)
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                            .foregroundColor(.purple)
                            .disabled(subject.isEmpty)
                        }
                        .padding()
                    } else {
                        HStack {
                            Text("Subject: \(subject)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("Change") {
                                withAnimation {
                                    isEditingSubject = true
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                    }
                }
                .padding(.top)
                .background(Color.purple)
                
                if !isEditingSubject {
                    QuizRoadmapView(subject: subject, service: service)
                } else {
                    Spacer()
                    Text("Enter a subject to see your roadmap")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                QuizHistoryView()
            }
            .onAppear {
                // Restore saved subject and progress on appear
                if !subject.isEmpty {
                    isEditingSubject = false
                    service.loadProgress(for: subject)
                }
            }
        }
    }
}

class QuizServiceWrapper: ObservableObject {
    @Published var unlockedLevel: Int = 1
    @Published var isLoading: Bool = false
    
    func loadProgress(for subject: String) {
        // Load from cache immediately
        unlockedLevel = QuizService.shared.getUnlockedLevel(for: subject)
        
        // Then fetch from backend asynchronously
        isLoading = true
        Task { @MainActor in
            let level = await QuizService.shared.getUnlockedLevel(for: subject)
            self.unlockedLevel = level
            self.isLoading = false
        }
    }
    
    func refresh(for subject: String) {
        loadProgress(for: subject)
    }
}

struct QuizRoadmapView: View {
    let subject: String
    @ObservedObject var service: QuizServiceWrapper
    @State private var selectedLevel: Int?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                ForEach(1...10, id: \.self) { level in
                    LevelNode(
                        level: level,
                        isUnlocked: level <= service.unlockedLevel,
                        isCompleted: level < service.unlockedLevel,
                        action: {
                            if level <= service.unlockedLevel {
                                selectedLevel = level
                            }
                        }
                    )
                    
                    if level < 10 {
                        Rectangle()
                            .fill(level < service.unlockedLevel ? Color.purple : Color.gray.opacity(0.3))
                            .frame(width: 4, height: 40)
                    }
                }
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .fullScreenCover(item: $selectedLevel) { level in
            QuizGameView(subject: subject, level: level) {
                service.refresh(for: subject)
            }
        }
    }
}

extension Int: Identifiable {
    public var id: Int { self }
}

struct LevelNode: View {
    let level: Int
    let isUnlocked: Bool
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 80, height: 80)
                    .shadow(color: backgroundColor.opacity(0.5), radius: 10, x: 0, y: 5)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.title.bold())
                        .foregroundColor(.white)
                } else if isUnlocked {
                    Text("\(level)")
                        .font(.title.bold())
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .disabled(!isUnlocked)
    }
    
    var backgroundColor: Color {
        if isCompleted { return .green }
        if isUnlocked { return .purple }
        return .gray
    }
}

struct QuizGameView: View {
    let subject: String
    let level: Int
    var onFinish: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var questions: [QuizQuestion] = []
    @State private var currentQuestionIndex = 0
    @State private var score = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showResult = false
    @State private var selectedOptionIndex: Int?
    @State private var isAnswerChecked = false
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Button("Quit") { dismiss() }
                Spacer()
                Text("Level \(level)")
                    .font(.headline)
                Spacer()
                Text("\(currentQuestionIndex + 1)/\(questions.count)")
            }
            .padding()
            
            if isLoading {
                Spacer()
                ProgressView("Generating Quiz with AI...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error).foregroundColor(.red)
                Button("Retry") { loadQuiz() }
                Spacer()
            } else if showResult {
                VStack(spacing: 20) {
                    Text(passed ? "Level Complete!" : "Level Failed")
                        .font(.largeTitle.bold())
                        .foregroundColor(passed ? .green : .red)
                    
                    Text("Score: \(score)/\(questions.count)")
                        .font(.title)
                    
                    if passed {
                        Text("You have unlocked the next level!")
                            .foregroundColor(.secondary)
                    } else {
                        Text("You need 50% to pass.")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Continue") {
                        saveAndDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Question View
                VStack(spacing: 24) {
                    ProgressView(value: Double(currentQuestionIndex), total: Double(questions.count))
                        .tint(.purple)
                    
                    Text(currentQuestion.question)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    VStack(spacing: 12) {
                        ForEach(0..<currentQuestion.options.count, id: \.self) { index in
                            Button {
                                if !isAnswerChecked {
                                    selectedOptionIndex = index
                                    checkAnswer()
                                }
                            } label: {
                                HStack {
                                    Text(currentQuestion.options[index])
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if isAnswerChecked {
                                        if index == currentQuestion.correctAnswerIndex {
                                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                        } else if index == selectedOptionIndex {
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(optionBackground(for: index))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(optionBorder(for: index), lineWidth: 2)
                                        )
                                )
                            }
                            .disabled(isAnswerChecked)
                        }
                    }
                    .padding(.horizontal)
                    
                    if isAnswerChecked {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Explanation:")
                                .font(.headline)
                            Text(currentQuestion.explanation)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Next Question") {
                                nextQuestion()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .padding(.top)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding()
                    }
                    
                    Spacer()
                }
            }
        }
        .task {
            loadQuiz()
        }
    }
    
    private var currentQuestion: QuizQuestion {
        questions[currentQuestionIndex]
    }
    
    private var passed: Bool {
        Double(score) / Double(questions.count) >= 0.5
    }
    
    private func loadQuiz() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                questions = try await QuizService.shared.generateQuiz(subject: subject, level: level)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func checkAnswer() {
        isAnswerChecked = true
        if selectedOptionIndex == currentQuestion.correctAnswerIndex {
            score += 1
        }
    }
    
    private func nextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
            selectedOptionIndex = nil
            isAnswerChecked = false
        } else {
            showResult = true
        }
    }
    
    private func optionBackground(for index: Int) -> Color {
        if isAnswerChecked {
            if index == currentQuestion.correctAnswerIndex {
                return Color.green.opacity(0.2)
            } else if index == selectedOptionIndex {
                return Color.red.opacity(0.2)
            }
        }
        return Color(.systemBackground)
    }
    
    private func optionBorder(for index: Int) -> Color {
        if isAnswerChecked {
            if index == currentQuestion.correctAnswerIndex {
                return .green
            } else if index == selectedOptionIndex {
                return .red
            }
        }
        return .clear
    }
    
    private func saveAndDismiss() {
        let result = QuizResult(
            id: UUID().uuidString,
            skill: subject,
            level: level,
            score: score,
            totalQuestions: questions.count
        )
        QuizService.shared.saveResult(result)
        onFinish()
        dismiss()
    }
}

struct QuizHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var history: [QuizResult] = []
    
    var body: some View {
        NavigationView {
            List(history) { result in
                VStack(alignment: .leading) {
                    HStack {
                        Text(result.skill)
                            .font(.headline)
                        Spacer()
                        Text("Level \(result.level)")
                            .font(.subheadline)
                            .padding(4)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    HStack {
                        Text("Score: \(result.score)/\(result.totalQuestions)")
                            .foregroundColor(Double(result.score)/Double(result.totalQuestions) >= 0.5 ? .green : .red)
                        Spacer()
                        Text(result.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Quiz History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                history = QuizService.shared.getHistory()
            }
        }
    }
}
