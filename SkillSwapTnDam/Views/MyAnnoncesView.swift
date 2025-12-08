//
//  MyAnnoncesView.swift
//  SkillSwapTnDam
//

import SwiftUI

struct MyAnnoncesView: View {
    @EnvironmentObject private var auth: AuthenticationManager

    @State private var annonces: [Annonce] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editingAnnonce: Annonce?
    @State private var annonceToDelete: Annonce?
    @State private var searchText: String = ""
    @State private var selectedCategory: String?
    @State private var selectedCity: String?
    @State private var withImageOnly: Bool = false
    @State private var sort: SortOption = .titleAsc

    private let service = AnnonceService()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                searchBar(text: $searchText, placeholder: "Rechercher une annonce")
                    .padding(.horizontal)

                if isLoading {
                    ProgressView("Chargement...")
                        .padding(.top, 40)
                } else if let errorMessage {
                    Text(errorMessage).foregroundColor(.red).padding()
                } else if annonces.isEmpty {
                    emptyStateView
                } else {
                    let items = displayedAnnonces
                    if items.isEmpty {
                        Text("Aucun resultat pour vos filtres/recherche.")
                            .foregroundColor(.secondary).padding(.top, 40)
                    } else {
                        ForEach(items) { annonce in
                            annonceCard(annonce).padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Mes annonces")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section("Trier") {
                        Picker("Trier", selection: $sort) {
                            Text("Titre (A-Z)").tag(SortOption.titleAsc)
                            Text("Titre (Z-A)").tag(SortOption.titleDesc)
                        }
                    }
                    Section("Filtres") {
                        Toggle("Avec image seulement", isOn: $withImageOnly)
                        Picker("Categorie", selection: $selectedCategory) {
                            Text("Toutes").tag(nil as String?)
                            ForEach(availableCategories, id: \.self) { cat in
                                Text(cat).tag(Optional(cat))
                            }
                        }
                        Picker("Ville", selection: $selectedCity) {
                            Text("Toutes").tag(nil as String?)
                            ForEach(availableCities, id: \.self) { city in
                                Text(city).tag(Optional(city))
                            }
                        }
                    }
                    Button("Reinitialiser filtres") { resetFilters() }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task { await loadAnnonces() }
        .sheet(item: $editingAnnonce) { annonce in
            EditAnnonceView(annonce: annonce) { updated in
                if let idx = annonces.firstIndex(where: { $0.id == updated.id }) {
                    annonces[idx] = updated
                }
            }
        }
        .alert(item: $annonceToDelete) { annonce in
            Alert(
                title: Text("Supprimer l'annonce ?"),
                message: Text("Voulez-vous vraiment supprimer cette annonce ?"),
                primaryButton: .destructive(Text("Supprimer")) {
                    Task { await deleteAnnonce(annonce) }
                },
                secondaryButton: .cancel(Text("Annuler"))
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60)).foregroundColor(.secondary)
            Text("Aucune annonce").font(.title2.bold())
            Text("Creez votre premiere annonce pour commencer")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    private func annonceCard(_ annonce: Annonce) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let uiImage = AnnonceImageStore.shared.loadImage(for: annonce.id) {
                    Image(uiImage: uiImage).resizable().scaledToFill().frame(height: 180).clipped()
                } else if let url = annonce.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill().frame(height: 180).clipped()
                        case .failure: placeholderImage
                        case .empty: ProgressView().frame(height: 180)
                        @unknown default: placeholderImage
                        }
                    }
                } else {
                    placeholderImage
                }

                if let category = annonce.category, !category.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            Text(category).font(.caption.bold())
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.ultraThinMaterial).clipShape(Capsule()).padding(12)
                        }
                        Spacer()
                    }
                }

                if annonce.isNew {
                    VStack {
                        HStack {
                            Text("NOUVEAU").font(.caption2.bold()).foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.green).clipShape(Capsule()).padding(12)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 180)

            VStack(alignment: .leading, spacing: 10) {
                Text(annonce.title).font(.headline).lineLimit(2)
                Text(annonce.description).font(.subheadline).foregroundColor(.secondary).lineLimit(3)
                Divider()
                HStack {
                    if let city = annonce.city, !city.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse").font(.caption)
                            Text(city).font(.caption)
                        }.foregroundColor(.secondary)
                    }
                    Spacer()
                    if let date = annonce.createdAtDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar").font(.caption)
                            Text(date, style: .date).font(.caption)
                        }.foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    Button { editingAnnonce = annonce } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Modifier")
                        }
                        .font(.subheadline.bold()).frame(maxWidth: .infinity)
                        .padding(.vertical, 10).background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue).cornerRadius(8)
                    }
                    Button { annonceToDelete = annonce } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Supprimer")
                        }
                        .font(.subheadline.bold()).frame(maxWidth: .infinity)
                        .padding(.vertical, 10).background(Color.red.opacity(0.1))
                        .foregroundColor(.red).cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private var placeholderImage: some View {
        ZStack {
            Color(.systemGray5)
            VStack(spacing: 8) {
                Image(systemName: "photo").font(.system(size: 40)).foregroundColor(.secondary)
                Text("Aucune image").font(.caption).foregroundColor(.secondary)
            }
        }.frame(height: 180)
    }

    private func searchBar(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(placeholder, text: text).textInputAutocapitalization(.never).autocorrectionDisabled(true)
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(12).background(Color(.systemBackground)).cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private enum SortOption: String, CaseIterable, Identifiable {
        case titleAsc, titleDesc
        var id: String { rawValue }
    }

    private var availableCategories: [String] {
        Array(Set(annonces.compactMap { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }

    private var availableCities: [String] {
        Array(Set(annonces.compactMap { $0.city?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }

    private var displayedAnnonces: [Annonce] {
        var items = annonces
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            items = items.filter {
                $0.title.lowercased().contains(q) ||
                $0.description.lowercased().contains(q) ||
                ($0.city?.lowercased().contains(q) ?? false) ||
                ($0.category?.lowercased().contains(q) ?? false)
            }
        }
        if let cat = selectedCategory, !cat.isEmpty { items = items.filter { $0.category == cat } }
        if let city = selectedCity, !city.isEmpty { items = items.filter { $0.city == city } }
        if withImageOnly {
            items = items.filter {
                AnnonceImageStore.shared.loadImage(for: $0.id) != nil || ($0.imageUrl?.isEmpty == false)
            }
        }
        switch sort {
        case .titleAsc: items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleDesc: items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
        return items
    }

    private func resetFilters() {
        searchText = ""
        selectedCategory = nil
        selectedCity = nil
        withImageOnly = false
        sort = .titleAsc
    }

    private func loadAnnonces() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            annonces = try await service.fetchMyAnnonces()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAnnonce(_ annonce: Annonce) async {
        do {
            try await service.deleteAnnonce(id: annonce.id)
            await MainActor.run {
                annonces.removeAll { $0.id == annonce.id }
                AnnonceImageStore.shared.deleteImage(for: annonce.id)
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
