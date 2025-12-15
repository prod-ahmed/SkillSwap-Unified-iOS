//
//  MyPromosView.swift
//  SkillSwapTnDam
//

import SwiftUI

struct MyPromosView: View {
    @EnvironmentObject private var auth: AuthenticationManager

    @State private var promos: [Promo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var promoToDelete: Promo?
    @State private var promoToEdit: Promo?
    @State private var showingCreateSheet = false
    @State private var searchText: String = ""
    @State private var showOnlyActive: Bool = false
    @State private var minDiscount: Int = 0
    @State private var sort: SortOption = .endDateAsc

    private let service = PromoService()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                searchBar(text: $searchText, placeholder: "Rechercher une promo")
                    .padding(.horizontal)

                if isLoading {
                    ProgressView("Chargement...")
                        .padding(.top, 40)
                } else if let errorMessage {
                    Text(errorMessage).foregroundColor(.red).padding()
                } else if promos.isEmpty {
                    emptyStateView
                } else {
                    let items = displayedPromos
                    if items.isEmpty {
                        Text("Aucun resultat pour vos filtres/recherche.")
                            .foregroundColor(.secondary).padding(.top, 40)
                    } else {
                        ForEach(items) { promo in
                            promoCard(promo).padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Mes promos")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section("Trier") {
                        Picker("Trier", selection: $sort) {
                            Text("Date de fin (proche)").tag(SortOption.endDateAsc)
                            Text("Date de fin (loin)").tag(SortOption.endDateDesc)
                            Text("Reduction (max)").tag(SortOption.discountDesc)
                        }
                    }
                    Section("Filtres") {
                        Toggle("Actives seulement", isOn: $showOnlyActive)
                        Picker("Reduction min.", selection: $minDiscount) {
                            Text("Toutes").tag(0)
                            Text(">= 10%").tag(10)
                            Text(">= 20%").tag(20)
                            Text(">= 30%").tag(30)
                            Text(">= 50%").tag(50)
                        }
                    }
                    Button("Reinitialiser filtres") { resetFilters() }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task { await loadPromos() }
        .alert("Supprimer cette promo ?",
               isPresented: Binding(
                    get: { promoToDelete != nil },
                    set: { if !$0 { promoToDelete = nil } }
               ),
               actions: {
                    Button("Annuler", role: .cancel) { promoToDelete = nil }
                    if let promo = promoToDelete {
                        Button("Supprimer", role: .destructive) {
                            Task { await deletePromo(promo) }
                        }
                    }
               },
               message: {
                    if let promo = promoToDelete {
                        Text("Voulez-vous vraiment supprimer \(promo.title) ?")
                    }
               }
        )
        .sheet(item: $promoToEdit) { promo in
            EditPromoView(
                promo: promo,
                onUpdated: { updated in
                    if let index = promos.firstIndex(where: { $0.id == updated.id }) {
                        promos[index] = updated
                    }
                }
            )
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreatePromoView(onPromoCreated: { newPromo in
                promos.insert(newPromo, at: 0)
            })
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.slash")
                .font(.system(size: 60)).foregroundColor(.secondary)
            Text("Aucune promo").font(.title2.bold())
            Text("Creez votre premiere promo pour commencer")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    private func promoCard(_ promo: Promo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let uiImage = PromoImageStore.shared.loadImage(for: promo.id) {
                    Image(uiImage: uiImage).resizable().scaledToFill().frame(height: 180).clipped()
                } else if let url = promo.imageURL {
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

                // Discount badge
                VStack {
                    HStack {
                        Text("-\(promo.discount)%")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .clipShape(Capsule())
                            .padding(12)
                        Spacer()
                    }
                    Spacer()
                }

                // Active/Expired badge
                VStack {
                    HStack {
                        Spacer()
                        if let date = promo.validUntilDate {
                            let isActive = date >= Date()
                            Text(isActive ? "ACTIVE" : "EXPIREE")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isActive ? Color.blue : Color.gray)
                                .clipShape(Capsule())
                                .padding(12)
                        }
                    }
                    Spacer()
                }
            }
            .frame(height: 180)

            VStack(alignment: .leading, spacing: 10) {
                Text(promo.title).font(.headline).lineLimit(2)
                Text(promo.description).font(.subheadline).foregroundColor(.secondary).lineLimit(3)
                
                // Promo code if available
                if let code = promo.promoCode, !code.isEmpty {
                    HStack {
                        Image(systemName: "ticket")
                        Text("Code: \(code)")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Divider()
                
                HStack {
                    // Valid until
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock").font(.caption)
                        Text("Valide jusqu'au: \(promo.validUntil)").font(.caption)
                    }.foregroundColor(.secondary)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Button { promoToEdit = promo } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Modifier")
                        }
                        .font(.subheadline.bold()).frame(maxWidth: .infinity)
                        .padding(.vertical, 10).background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue).cornerRadius(8)
                    }
                    Button { promoToDelete = promo } label: {
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
            LinearGradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 8) {
                Image(systemName: "tag.fill").font(.system(size: 40)).foregroundColor(.white.opacity(0.8))
                Text("Promo").font(.caption).foregroundColor(.white.opacity(0.8))
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
        case endDateAsc, endDateDesc, discountDesc
        var id: String { rawValue }
    }

    private var displayedPromos: [Promo] {
        var items = promos
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            items = items.filter {
                $0.title.lowercased().contains(q) ||
                $0.description.lowercased().contains(q) ||
                ($0.promoCode?.lowercased().contains(q) ?? false)
            }
        }
        if showOnlyActive {
            let now = Date()
            items = items.filter { promo in
                if let d = promo.validUntilDate { return d >= now }
                return true
            }
        }
        if minDiscount > 0 {
            items = items.filter { $0.discount >= minDiscount }
        }
        switch sort {
        case .endDateAsc: items.sort { ($0.validUntilDate ?? .distantFuture) < ($1.validUntilDate ?? .distantFuture) }
        case .endDateDesc: items.sort { ($0.validUntilDate ?? .distantPast) > ($1.validUntilDate ?? .distantPast) }
        case .discountDesc: items.sort { $0.discount > $1.discount }
        }
        return items
    }

    private func resetFilters() {
        searchText = ""
        showOnlyActive = false
        minDiscount = 0
        sort = .endDateAsc
    }

    private func loadPromos() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            promos = try await service.fetchMyPromos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePromo(_ promo: Promo) async {
        do {
            try await service.deletePromo(id: promo.id)
            await MainActor.run {
                promos.removeAll { $0.id == promo.id }
                promoToDelete = nil
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
