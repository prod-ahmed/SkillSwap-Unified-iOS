//
//  CreateAnnonceView.swift
//  SkillSwapTnDam
//
//  Created by Ahmed BT on 15/11/2025.
//

import SwiftUI
import PhotosUI

struct CreateAnnonceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthenticationManager

    @State private var title = ""
    @State private var description = ""
    @State private var city = ""
    @State private var category = ""
    @State private var cities: [String] = []
    @State private var showCitySuggestions = false

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?

    @State private var isSaving = false
    @State private var isCheckingImage = false
    @State private var errorMessage: String?
    @State private var showModerationAlert = false
    @State private var moderationMessage = ""
    @State private var imageRejected = false
    @State private var isImageSafe = true

    @State private var isGeneratingAI = false
    @State private var showAIPrompt = false
    @State private var aiPrompt = ""
    
    private let service = AnnonceService()
    private let moderationService = ModerationService()

    var onAnnonceCreated: ((Annonce) -> Void)?
    
    private var filteredCities: [String] {
        if city.isEmpty {
            return cities
        }
        return cities.filter { $0.localizedCaseInsensitiveContains(city) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showAIPrompt = true
                    } label: {
                        Label("Auto-create with AI", systemImage: "wand.and.stars")
                            .foregroundColor(.purple)
                    }
                }
                
                Section("Annonce") {
                    if isGeneratingAI {
                        HStack {
                            Spacer()
                            ProgressView("Generating content...")
                            Spacer()
                        }
                    }
                    TextField("Titre", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Détails") {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Ville (optionnel)", text: $city)
                            .onChange(of: city) { _ in
                                showCitySuggestions = !city.isEmpty
                            }
                        
                        if showCitySuggestions && !filteredCities.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(filteredCities.prefix(5), id: \.self) { cityName in
                                        Button {
                                            city = cityName
                                            showCitySuggestions = false
                                        } label: {
                                            HStack {
                                                Text(cityName)
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
                                        
                                        if cityName != filteredCities.prefix(5).last {
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
                    
                    TextField("Catégorie (optionnel)", text: $category)
                }

                Section("Image") {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images
                    ) {
                        Label("Choisir une image", systemImage: "photo.on.rectangle")
                    }

                    if let data = selectedImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                            .frame(maxHeight: 200)
                    }
                    
                    if isCheckingImage {
                        HStack {
                            ProgressView()
                            Text("Vérification de l'image...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }

                if let err = errorMessage {
                    Section { Text(err).foregroundColor(.red) }
                }
            }
            .navigationTitle("Créer une annonce")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Publier") {
                        Task { await save() }
                    }
                    .disabled(isSaving || title.isEmpty || description.isEmpty || imageRejected || !isImageSafe)
                }
            }
            .onChange(of: selectedItem) { item in
                Task { await loadImage(item) }
            }
            .task {
                await fetchCities()
            }
            .alert("Contenu inapproprié", isPresented: $showModerationAlert) {
                Button("OK", role: .cancel) {
                    // Clear the selected image and mark as rejected
                    selectedImageData = nil
                    selectedItem = nil
                    imageRejected = true
                }
            } message: {
                Text(moderationMessage)
            }
            .alert("AI Auto-Create", isPresented: $showAIPrompt) {
                TextField("What do you want to teach/learn?", text: $aiPrompt)
                Button("Generate") {
                    Task { await generateWithAI() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Describe your skill briefly (e.g. 'I want to teach guitar beginners')")
            }
        }
    }
    
    private func generateWithAI() async {
        isGeneratingAI = true
        do {
            let (genTitle, genDesc, genCat) = try await service.generateAnnonceContent(prompt: aiPrompt)
            await MainActor.run {
                self.title = genTitle
                self.description = genDesc
                self.category = genCat
                self.isGeneratingAI = false
            }
        } catch {
            await MainActor.run {
                self.isGeneratingAI = false
                // Handle quota error specifically as requested
                if (error as NSError).code == 429 {
                     self.errorMessage = "Quota reached until we change get the api key"
                } else {
                     self.errorMessage = "AI Generation failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        // Reset rejection flag when selecting new image
        await MainActor.run {
            imageRejected = false
            isImageSafe = false
        }
        if let data = try? await item.loadTransferable(type: Data.self) {
            // Check moderation before setting the image
            await checkImageModeration(data)
        }
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
    
    private func checkImageModeration(_ imageData: Data) async {
        guard auth.isAuthenticated, let token = auth.accessToken else {
            print("⚠️ No auth token, skipping moderation")
            await MainActor.run {
                selectedImageData = imageData
                isImageSafe = true
            }
            return
        }
        
        await MainActor.run {
            isCheckingImage = true
        }
        
        do {
            print("🔍 Starting moderation check...")
            let result = try await moderationService.checkImage(imageData: imageData, accessToken: token)
            print("✅ Moderation result: safe=\(result.safe), categories=\(result.categories ?? [])")
            
            await MainActor.run {
                isCheckingImage = false
                
                if result.safe {
                    // Image is safe, allow it
                    selectedImageData = imageData
                    isImageSafe = true
                } else {
                    // Image is not safe, show alert
                    let categories = result.categories?.joined(separator: ", ") ?? "contenu inapproprié"
                    moderationMessage = "At least one of your images has bad content (\(categories)). Please rectify before publishing."
                    showModerationAlert = true
                    imageRejected = true
                    isImageSafe = false
                }
            }
        } catch {
            // Show error to user instead of silently allowing
            print("❌ Moderation error: \(error.localizedDescription)")
            await MainActor.run {
                isCheckingImage = false
                moderationMessage = "Erreur lors de la vérification de l'image: \(error.localizedDescription). Veuillez réessayer."
                showModerationAlert = true
                imageRejected = true
                isImageSafe = false
            }
        }
    }

    private func save() async {
        // Ensure we have a token (backend requires auth)
        guard auth.isAuthenticated, AuthenticationManager.shared.accessToken != nil else {
            errorMessage = "Vous devez être connecté pour publier une annonce."
            return
        }
        
        // Check if image was rejected
        if imageRejected {
            await MainActor.run {
                moderationMessage = "Votre image a été rejetée pour contenu inapproprié. Veuillez sélectionner une autre image."
                showModerationAlert = true
            }
            return
        }
        
        // If there's an image, verify it one more time before publishing
        if let imageData = selectedImageData {
            guard let token = auth.accessToken else { return }
            
            isSaving = true
            defer { isSaving = false }
            
            do {
                print("🔍 Final moderation check before publishing...")
                let result = try await moderationService.checkImage(imageData: imageData, accessToken: token)
                print("✅ Final check result: safe=\(result.safe)")
                
                if !result.safe {
                    // Image is not safe, block the save
                    await MainActor.run {
                        let categories = result.categories?.joined(separator: ", ") ?? "contenu inapproprié"
                        moderationMessage = "Votre image contient du contenu inapproprié (\(categories)). Veuillez la modifier ou en choisir une autre."
                        showModerationAlert = true
                        imageRejected = true
                    }
                    return
                }
            } catch {
                // If moderation check fails, block the save
                await MainActor.run {
                    moderationMessage = "Impossible de vérifier votre image. Veuillez réessayer."
                    showModerationAlert = true
                }
                return
            }
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            // Create the annonce first
            let created = try await service.create(
                title: title,
                description: description,
                imageUrl: nil,
                city: city.isEmpty ? nil : city,
                category: category.isEmpty ? nil : category
            )

            // If there's an image, upload it
            if let data = selectedImageData {
                let filename = "annonce_\(created.id)_\(Date().timeIntervalSince1970).jpg"
                _ = try await service.uploadImage(id: created.id, imageData: data, filename: filename)
            }

            onAnnonceCreated?(created)
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func ensureImagesAreSafeBeforePublishing() async -> Bool {
        if isCheckingImage {
            moderationMessage = "Image moderation is still running. Please wait before publishing."
            showModerationAlert = true
            return false
        }

        if selectedImageData != nil && (!isImageSafe || imageRejected) {
            moderationMessage = "At least one of your images has bad content. Please rectify before publishing."
            showModerationAlert = true
            return false
        }

        return true
    }
}
