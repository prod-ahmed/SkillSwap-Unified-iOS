import SwiftUI
import PhotosUI

struct CreatePromoView: View {
    @Environment(\.dismiss) private var dismiss

    // callback vers la vue parente
    var onPromoCreated: ((Promo) -> Void)?



    // Form fields
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var discountText: String = ""
    @State private var validUntil: Date = .now.addingTimeInterval(TimeInterval(60 * 60 * 24 * 7))

    // Image picker
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?

    // State
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    // Moderation State
    @State private var showModerationAlert = false
    @State private var moderationMessage = ""
    @State private var imageRejected = false
    @State private var isCheckingImage = false
    @State private var isGeneratingImage = false
    
    // Services
    private let service = PromoService()
    private let moderationService = ModerationService()
    @EnvironmentObject private var auth: AuthenticationManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Titre", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)

                    TextField("Réduction (%)", text: $discountText)
                        .keyboardType(.numberPad)

                    DatePicker(
                        "Valable jusqu'au",
                        selection: $validUntil,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Image") {
                    if isGeneratingImage {
                        HStack {
                            Spacer()
                            ProgressView("Génération de l'image IA...")
                            Spacer()
                        }
                    } else {
                        Button {
                            Task { await generateAIBanner() }
                        } label: {
                            Label("Générer une bannière IA", systemImage: "sparkles")
                        }
                        .disabled(title.isEmpty)
                        
                        PhotosPicker("Choisir une image",
                                     selection: $selectedItem,
                                     matching: .images)
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
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Nouvelle promo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Enregistrer")
                        }
                    }
                    .disabled(isSaving || isCheckingImage || imageRejected)
                }
            }
            // 🔥 plus fiable que .task(id:)
            .onChange(of: selectedItem) { newItem in
                Task { await loadImage(from: newItem) }
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

    // MARK: - AI Generation
    
    private func generateAIBanner() async {
        guard !title.isEmpty else { return }
        
        isGeneratingImage = true
        errorMessage = nil
        
        do {
            let prompt = "Marketing banner for: \(title). \(description)"
            let imageData = try await service.generateBannerImage(prompt: prompt)
            
            await MainActor.run {
                selectedImageData = imageData
                selectedItem = nil // Clear picker selection as we used AI
                isGeneratingImage = false
            }
            
            // Check moderation on the generated image
            await checkImageModeration(imageData)
            
        } catch {
            await MainActor.run {
                isGeneratingImage = false
                errorMessage = "Erreur lors de la génération: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Image loading

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
            } else {
                await MainActor.run {
                    print("⚠️ loadTransferable a retourné nil")
                }
            }
        } catch {
            print("❌ Failed to load image data: \(error)")
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

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        guard let discount = Int(discountText) else {
            errorMessage = "La réduction doit être un nombre."
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
            
            // Temporarily set isSaving to true (already true)
            
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

        do {
            // Create the promo first
            let created = try await service.create(
                title: title,
                description: description,
                discountPercent: discount,
                validFrom: Date(),
                validTo: validUntil,
                promoCode: nil,
                imageUrl: nil
            )

            // If there's an image, upload it
            if let data = selectedImageData {
                let filename = "promo_\(created.id)_\(Date().timeIntervalSince1970).jpg"
                _ = try await service.uploadImage(id: created.id, imageData: data, filename: filename)
            }

            await MainActor.run {
                print("✅ Promo créée avec succès")
                onPromoCreated?(created)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}
