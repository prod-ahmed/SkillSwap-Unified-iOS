//
//  EditAnnonceView.swift
//  SkillSwapTnDam
//
//  Created by Ahmed BT on 16/11/2025.
//

import SwiftUI
import PhotosUI
import UIKit

struct EditAnnonceView: View {
    @Environment(\.dismiss) private var dismiss

    let annonce: Annonce
    var onUpdated: (Annonce) -> Void

    @State private var title: String
    @State private var description: String
    @State private var city: String
    @State private var category: String
    @State private var cities: [String] = []
    @State private var showCitySuggestions = false

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?

    @State private var isSaving = false
    @State private var errorMessage: String?
    
    // Moderation State
    @State private var showModerationAlert = false
    @State private var moderationMessage = ""
    @State private var imageRejected = false
    @State private var isCheckingImage = false

    private let service = AnnonceService()
    private let moderationService = ModerationService()
    @EnvironmentObject private var auth: AuthenticationManager

    init(annonce: Annonce, onUpdated: @escaping (Annonce) -> Void) {
        self.annonce = annonce
        self.onUpdated = onUpdated
        _title = State(initialValue: annonce.title)
        _description = State(initialValue: annonce.description)
        _city = State(initialValue: annonce.city ?? "")
        _category = State(initialValue: annonce.category ?? "")
    }
    
    private var filteredCities: [String] {
        if city.isEmpty {
            return cities
        }
        return cities.filter { $0.localizedCaseInsensitiveContains(city) }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Annonce") {
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
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Changer l’image")
                        }
                    }

                    if isCheckingImage {
                        HStack {
                            Spacer()
                            ProgressView("Vérification...")
                            Spacer()
                        }
                    } else if let data = selectedImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                    } else if let uiImage = AnnonceImageStore.shared.loadImage(for: annonce.id) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Modifier l’annonce")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Enregistrer") {
                            Task { await save() }
                        }
                        .disabled(isSaving || isCheckingImage || imageRejected)
                    }
                }
            }
            .onChange(of: selectedItem) { item in
                Task { await loadImage(from: item) }
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
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        
        // Reset rejection flag when selecting new image
        await MainActor.run {
            imageRejected = false
        }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                // Check moderation before setting the image
                await checkImageModeration(data)
            }
        } catch {
            print("Failed to load image data: \(error)")
        }
    }
    
    private func checkImageModeration(_ imageData: Data) async {
        guard auth.isAuthenticated, let token = auth.accessToken else {
            print("⚠️ No auth token, skipping moderation")
            await MainActor.run {
                selectedImageData = imageData
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
                } else {
                    // Image is not safe, show alert
                    let categories = result.categories?.joined(separator: ", ") ?? "contenu inapproprié"
                    moderationMessage = "Cette image contient du contenu qui n'est pas autorisé sur notre plateforme: \(categories). Veuillez choisir une autre image."
                    showModerationAlert = true
                }
            }
        } catch {
            // Show error to user instead of silently allowing
            print("❌ Moderation error: \(error.localizedDescription)")
            await MainActor.run {
                isCheckingImage = false
                moderationMessage = "Erreur lors de la vérification de l'image: \(error.localizedDescription). Veuillez réessayer."
                showModerationAlert = true
            }
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

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        // Check if image was rejected
        if imageRejected {
            await MainActor.run {
                moderationMessage = "Votre image a été rejetée pour contenu inapproprié. Veuillez sélectionner une autre image."
                showModerationAlert = true
            }
            return
        }
        
        // If there's a NEW image, verify it one more time before publishing
        if let imageData = selectedImageData {
            guard let token = auth.accessToken else { return }
            
            do {
                print("🔍 Final moderation check before updating...")
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

        do {
            let payload = AnnonceService.UpdateAnnoncePayload(
                title: title,
                description: description,
                imageUrl: annonce.imageUrl, // plus tard: vraie URL si upload
                city: city.isEmpty ? nil : city,
                category: category.isEmpty ? nil : category
            )

            // ⚠️ Assumes `annonce.id` is a String. If it's Int, change the
            // updateAnnonce signature accordingly in AnnonceService.
            var updated = try await service.updateAnnonce(id: annonce.id, payload: payload)

            if let data = selectedImageData {
                // FIX: use saveImage instead of saveImageData
                AnnonceImageStore.shared.saveImage(data, for: annonce.id)
                updated.imageData = data
            } else {
                updated.imageData = annonce.imageData
            }

            await MainActor.run {
                onUpdated(updated)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}
