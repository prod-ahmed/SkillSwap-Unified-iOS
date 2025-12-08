import SwiftUI

struct ProgressDashboardView: View {
    @StateObject private var viewModel = ProgressDashboardViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section { headerSection }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                goalsSection
                Section { weeklyActivitySection }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                Section { skillProgressSection }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                Section { badgesSection }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ma progression")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.presentGoalForm()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .alert("Erreur", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $viewModel.isPresentingGoalForm) {
                GoalFormView(viewModel: viewModel)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                StatCard(icon: "clock.fill", title: "Cette semaine", value: String(format: "%.1fh", viewModel.dashboard?.stats.weeklyHours ?? 0))
                StatCard(icon: "star.fill", title: "Compétences", value: "\(viewModel.dashboard?.stats.skillsCount ?? 0)")
            }
            if let xp = viewModel.dashboard?.xpSummary {
                HStack {
                    VStack(alignment: .leading) {
                        Text("XP total")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(xp.xp)")
                            .font(.title.bold())
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Prochain badge")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        if let next = xp.nextBadge {
                            Text(next.title)
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("À \(next.threshold) XP")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text("Tous débloqués")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                }
                referralSummary(count: xp.referralCount)
            }
        }
        .padding()
        .background(
            LinearGradient(colors: [Color(hex: "#00A8A8"), Color(hex: "#00B8B8")], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(32)
        .padding(.horizontal)
        .padding(.top)
    }

    private func referralSummary(count: Int) -> some View {
        HStack {
            Label {
                Text(count == 1 ? "Parrainage complété" : "Parrainages complétés")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "person.3.fill")
            }
            .foregroundColor(.white)
            Spacer()
            Text("\(count)")
                .font(.title3.bold())
                .foregroundColor(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.12))
        .cornerRadius(18)
    }

    @ViewBuilder
    private var goalsSection: some View {
        Section {
            HStack {
                Text("Objectifs")
                    .font(.headline)
                Spacer()
                Button("Ajouter") { viewModel.presentGoalForm() }
                    .font(.subheadline.bold())
            }
            .listRowSeparator(.hidden)
            if let goals = viewModel.dashboard?.goals, !goals.isEmpty {
                ForEach(goals) { goal in
                    let isDeleting = viewModel.deletingGoalId == goal.id
                    GoalCard(goal: goal)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                viewModel.startEditing(goal: goal)
                            } label: {
                                Label("Modifier", systemImage: "pencil")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                if !isDeleting {
                                    Task { await viewModel.deleteGoal(goal) }
                                }
                            } label: {
                                if isDeleting {
                                    ProgressView()
                                } else {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                            .disabled(isDeleting)
                        }
                }
            } else {
                Text("Ajoutez un objectif pour suivre vos heures d'apprentissage.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(24)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }
        }
        .textCase(nil)
    }

    private var weeklyActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activité de la semaine")
                .font(.headline)
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(viewModel.dashboard?.weeklyActivity ?? []) { point in
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")], startPoint: .bottom, endPoint: .top))
                                .frame(height: barHeight(for: point.hours, in: geometry.size.height))
                            Text(point.day)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 180)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(28)
        }
        .padding(.horizontal)
    }

    private var skillProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compétences en cours")
                .font(.headline)
            if let skills = viewModel.dashboard?.skillProgress, !skills.isEmpty {
                ForEach(skills) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.skill)
                                    .font(.headline)
                                Text(String(format: "%.1f h • %@", item.hours, item.level))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(item.progress)%")
                                .font(.subheadline.bold())
                        }
                        ProgressView(value: Double(item.progress) / 100)
                            .tint(Color(hex: "#FF6B35"))
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(24)
                }
            } else {
                Text("Commencez des sessions pour voir vos progrès.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(24)
            }
        }
        .padding(.horizontal)
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(viewModel.dashboard?.badges ?? []) { badge in
                    VStack {
                        Text(badge.displayIcon)
                            .font(.largeTitle)
                        Text(badge.displayName)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                        if !badge.unlocked {
                            Text("À \(badge.threshold)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        Color(hex: badge.color)
                            .opacity(badge.unlocked ? 0.2 : 0.08)
                    )
                    .overlay(
                        Group {
                            if !badge.unlocked {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                    .padding(6)
                            }
                        }, alignment: .topTrailing
                    )
                    .opacity(badge.unlocked ? 1 : 0.6)
                    .cornerRadius(20)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func barHeight(for hours: Double, in totalHeight: CGFloat) -> CGFloat {
        guard let maxHours = viewModel.dashboard?.weeklyActivity.map({ $0.hours }).max(), maxHours > 0 else {
            return totalHeight * 0.1
        }
        let ratio = hours / maxHours
        return Swift.max(CGFloat(ratio) * (totalHeight - 20), 8)
    }
}

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "#00B8B8"))
                .font(.title2)
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }
}

private struct GoalCard: View {
    let goal: ProgressGoalItem

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.title)
                    .font(.headline)
                Spacer()
                Text(goal.period == "week" ? "Hebdo" : "Mensuel")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#FF6B35").opacity(0.1))
                    .cornerRadius(12)
                if goal.status == "completed" {
                    Label("Complété", systemImage: "checkmark.seal.fill")
                        .font(.caption2.bold())
                        .padding(6)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(12)
                }
            }
            Text(String(format: "%.1f h sur %.0f h", goal.currentHours, goal.targetHours))
                .font(.subheadline)
                .foregroundColor(.secondary)
            ProgressView(value: goal.progressRatio)
                .tint(Color(hex: "#FF6B35"))
            Text("\(goal.normalizedProgressPercent)%")
                .font(.caption)
                .foregroundColor(.secondary)
            if let dueDate = goal.dueDate {
                Text("Jusqu'au \(dateFormatter.string(from: dueDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(24)
    }
}

private struct GoalFormView: View {
    @ObservedObject var viewModel: ProgressDashboardViewModel

    var body: some View {
        let isEditing = viewModel.editingGoal != nil
        NavigationStack {
            Form {
                Section("Nom de l'objectif") {
                    TextField("4 heures d'apprentissage", text: $viewModel.newGoalTitle)
                }
                Section("Durée") {
                    Stepper(value: $viewModel.newGoalHours, in: 1...20, step: 0.5) {
                        Text(String(format: "%.1f heures", viewModel.newGoalHours))
                    }
                    Picker("Période", selection: $viewModel.newGoalPeriod) {
                        Text("Hebdomadaire").tag("week")
                        Text("Mensuelle").tag("month")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(isEditing ? "Modifier l'objectif" : "Nouvel objectif")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { viewModel.dismissGoalForm() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Mettre à jour" : "Enregistrer") {
                        Task { await viewModel.submitGoalForm() }
                    }
                    .disabled(viewModel.newGoalTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ProgressDashboardView()
        .environmentObject(AuthenticationManager.shared)
}
