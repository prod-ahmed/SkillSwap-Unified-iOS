import SwiftUI

struct AvailabilitySheet: View {
    let member: UserSuggestion
    let availability: AvailabilityResponse?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let availability {
                    if availability.isAvailable {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)
                            Text("\(member.username) est disponible pour cette plage horaire 🎉")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else if let conflicts = availability.conflictingSessions, !conflicts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Conflit détecté")
                                    .font(.headline)
                            }
                            
                            ForEach(conflicts.indices, id: \.self) { index in
                                let conflict = conflicts[index]
                                VStack(alignment: .leading, spacing: 4) {
                                    if let title = conflict.title {
                                        Text(title)
                                            .font(.subheadline.bold())
                                    }
                                    
                                    if let date = conflict.date {
                                        Text("Date : \(date)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let duration = conflict.duration {
                                        Text("Durée : \(duration) min")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    } else if let conflict = availability.conflict {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Conflit détecté")
                                    .font(.headline)
                            }
                            
                            if let title = conflict.title {
                                Text(title)
                                    .font(.subheadline)
                            }
                            
                            if let date = conflict.date {
                                Text("Date : \(date)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let duration = conflict.duration {
                                Text("Durée : \(duration) min")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    } else {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)
                            Text("Aucun conflit détecté pour cette date 🎉")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                } else {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("Aucune indisponibilité pour cette date 🎉")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Disponibilités de \(member.username)")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}
