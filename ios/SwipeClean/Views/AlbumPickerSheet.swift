//
//  AlbumPickerSheet.swift
//  SwipeClean
//
//  Modal sheet shown after swipe-right. Claude's suggestion is pinned at the top.
//  User can accept, pick an existing album, create a new one, or skip filing.
//

import SwiftUI

struct AlbumPickerSheet: View {

    let suggestedAlbum: AlbumSuggestionResult?
    let existingAlbums: [String]
    let onPick: (String) -> Void
    let onSkip: () -> Void

    @State private var showNewAlbumField = false
    @State private var newAlbumName = ""
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredAlbums: [String] {
        if searchText.isEmpty { return existingAlbums }
        return existingAlbums.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Claude's suggestion -- pinned at top
                if let suggested = suggestedAlbum {
                    Section {
                        Button {
                            onPick(suggested.name)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.yellow)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggested.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(suggested.isExisting ? "Existing album" : "Create new album")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                ConfidencePill(confidence: suggested.confidence)
                            }
                        }
                    } header: {
                        Text("Claude suggests")
                    } footer: {
                        Text("Based on the photo content and your existing albums.")
                    }
                }

                // Create new album
                Section("New album") {
                    if showNewAlbumField {
                        HStack {
                            TextField("Album name", text: $newAlbumName)
                                .textInputAutocapitalization(.words)
                                .onSubmit { commitNewAlbum() }
                            Button("Create") { commitNewAlbum() }
                                .disabled(newAlbumName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        Button {
                            showNewAlbumField = true
                        } label: {
                            Label("New album...", systemImage: "folder.badge.plus")
                        }
                    }
                }

                // Existing albums
                if !existingAlbums.isEmpty {
                    Section("Your albums") {
                        ForEach(filteredAlbums, id: \.self) { name in
                            Button {
                                onPick(name)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 28)
                                    Text(name)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }

                // Skip
                Section {
                    Button("Skip filing", role: .cancel) {
                        onSkip()
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .searchable(text: $searchText, prompt: "Search albums")
            .navigationTitle("File this photo?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onSkip()
                        dismiss()
                    }
                }
            }
        }
    }

    private func commitNewAlbum() {
        let name = newAlbumName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        onPick(name)
        dismiss()
    }
}

// MARK: - Confidence pill

private struct ConfidencePill: View {
    let confidence: Double

    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var color: Color {
        confidence >= 0.8 ? .green : confidence >= 0.5 ? .orange : .gray
    }
}
