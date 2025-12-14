 import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var auth: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var email: String = ""
    @State private var location: String = ""
    @State private var teachSkills: [String] = []
    @State private var learnSkills: [String] = []
    @State private var cities: [String] = []
    @State private var showCitySuggestions = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var originalUsername: String = ""
    @State private var originalLocation: String = ""

    private let userService = UserService()

    private var hasChanges: Bool {
        username != originalUsername || 
        location != originalLocation ||
        teachSkills != (auth.currentUser?.skillsTeach ?? []) ||
        learnSkills != (auth.currentUser?.skillsLearn ?? [])
    }

    private var canSave: Bool {
        auth.isAuthenticated && hasChanges && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var filteredCities: [String] {
        if location.isEmpty {
            return cities
        }
        return cities.filter { $0.localizedCaseInsensitiveContains(location) }
    }

    var body: some View {
        NavigationView {
            Group {
                if auth.isAuthenticated {
                    Form {
                        Section(header: Text("Informations personnelles")) {
                            TextField("Nom d'utilisateur", text: $username)

                            TextField("Email", text: $email)
                                .disabled(true)
                                .foregroundColor(.secondary)
                        }

                        Section(header: Text("Localisation")) {
                            VStack(alignment: .leading, spacing: 0) {
                                TextField("Ville", text: $location)
                                    .onChange(of: location) { _ in
                                        showCitySuggestions = !location.isEmpty
                                    }
                                
                                if showCitySuggestions && !filteredCities.isEmpty {
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 0) {
                                            ForEach(filteredCities.prefix(5), id: \.self) { city in
                                                Button {
                                                    location = city
                                                    showCitySuggestions = false
                                                } label: {
                                                    HStack {
                                                        Text(city)
                                                            .foregroundColor(.primary)
                                                        Spacer()
                                                        Image(systemName: "mappin.circle.fill")
                                                            .foregroundColor(.secondary)
                                                            .font(.caption)
                                                    }
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 12)
                                                    .background(Color(.secondarySystemGroupedBackground))
                                                }
                                                .buttonStyle(.plain)
                                                
                                                if city != filteredCities.prefix(5).last {
                                                    Divider()
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 200)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(8)
                                    .padding(.top, 4)
                                }
                            }
                        }

                        Section(header: Text("Compétences")) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Je peux enseigner")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                SkillChipsEditor(skills: $teachSkills, color: .orange)
                            }
                            .padding(.vertical, 8)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Je veux apprendre")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                SkillChipsEditor(skills: $learnSkills, color: .teal)
                            }
                            .padding(.vertical, 8)
                        }

                        if let errorMessage {
                            Section {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                            }
                        }

                        if let successMessage {
                            Section {
                                Text(successMessage)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Section {
                            Button(role: .destructive) {
                                auth.signOut()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Se déconnecter")
                                    Spacer()
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Connectez-vous pour modifier votre profil")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Paramètres du profil")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sauvegarder") {
                        Task { await saveChanges() }
                    }
                    .disabled(!canSave || isSaving)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Chargement...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
        .task {
            await loadProfile()
            await fetchCities()
        }
    }

    private func loadProfile() async {
        guard auth.isAuthenticated else { return }
        await MainActor.run {
            if let cached = auth.currentUser {
                applyUser(cached)
            }
        }

        guard let token = await MainActor.run(body: { auth.accessToken }) else { return }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
            successMessage = nil
        }

        do {
            let user = try await userService.fetchCurrentUser(accessToken: token)
            await MainActor.run {
                auth.saveCurrentUser(user)
                applyUser(user)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run { isLoading = false }
    }

    private func applyUser(_ user: User) {
        username = user.username
        email = user.email
        location = user.locationDisplay ?? ""
        teachSkills = user.skillsTeach ?? []
        learnSkills = user.skillsLearn ?? []
        originalUsername = username
        originalLocation = location
    }

    private func fetchCities() async {
        guard let url = URL(string: "\(NetworkConfig.baseURL)/locations/cities") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let fetchedCities = try? JSONDecoder().decode([String].self, from: data) {
                await MainActor.run {
                    self.cities = fetchedCities
                }
            }
        } catch {
            print("Error fetching cities: \(error)")
        }
    }

    private func saveChanges() async {
        guard auth.isAuthenticated else { return }
        guard let token = await MainActor.run(body: { auth.accessToken }) else { return }

        await MainActor.run {
            isSaving = true
            errorMessage = nil
            successMessage = nil
        }

        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let locationPayload: LocationPayload? = trimmedLocation.isEmpty ? nil : LocationPayload(lat: nil, lon: nil, city: trimmedLocation)

        let payload = UpdateUserRequest(
            username: username,
            email: nil,
            location: locationPayload,
            skillsTeach: teachSkills,
            skillsLearn: learnSkills,
            availability: nil
        )

        do {
            let updated = try await userService.updateCurrentUser(accessToken: token, payload: payload)
            await MainActor.run {
                auth.saveCurrentUser(updated)
                applyUser(updated)
                successMessage = "Profil mis à jour"
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run { isSaving = false }
    }
}

struct ProfileSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSettingsView()
            .environmentObject(AuthenticationManager.shared)
    }
}
