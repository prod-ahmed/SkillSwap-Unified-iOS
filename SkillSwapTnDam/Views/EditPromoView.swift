import SwiftUI
import PhotosUI
import UIKit

struct EditPromoView: View {
    @Environment(\.dismiss) private var dismiss

    let promo: Promo
    var onUpdated: (Promo) -> Void

    // Form fields
    @State private var title: String
    @State private var description: String
    @State private var discountText: String
    @State private var validUntil: Date
    @State private var promoCode: String

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

    private let service = PromoService()
    private let moderationService = ModerationService()
    @EnvironmentObject private var auth: AuthenticationManager

    init(promo: Promo, onUpdated: @escaping (Promo) -> Void) {
        self.promo = promo
        self.onUpdated = onUpdated

        _title = State(initialValue: promo.title)
        _description = State(initialValue: promo.description)
        _discountText = State(initialValue: String(promo.discount))
        _validUntil = State(initialValue: promo.validUntilDate ?? Date())
        _promoCode = State(initialValue: promo.promoCode ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Titre", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)

                    TextField("Réduction (%)", text: $discountText)
                        .keyboardType(.numberPad)

                    TextField("Code promo (optionnel)", text: $promoCode)

                    DatePicker(
                        "Valable jusqu'au",
                        selection: $validUntil,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Image") {
                    PhotosPicker("Changer l’image",
                                 selection: $selectedItem,
                                 matching: .images)

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
                    } else if let uiImage = PromoImageStore.shared.loadImage(for: promo.id) {
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
            .navigationTitle("Modifier la promo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
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
            let newPromoCode: String? = promoCode.isEmpty ? nil : promoCode

            var updated = try await service.updatePromo(
                id: promo.id,
                title: title == promo.title ? nil : title,
                description: description == promo.description ? nil : description,
                discountPercent: discount == promo.discount ? nil : discount,
                validFrom: nil, // not edited here
                validTo: (promo.validUntilDate == validUntil) ? nil : validUntil,
                promoCode: (newPromoCode == promo.promoCode) ? nil : newPromoCode,
                imageUrl: nil // no remote image upload; keep existing
            )

            // Save and attach local image if changed
            if let data = selectedImageData {
                PromoImageStore.shared.saveImageData(data, for: promo.id)
                updated.imageData = data
            } else {
                updated.imageData = promo.imageData
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
