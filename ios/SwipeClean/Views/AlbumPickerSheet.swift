//
//  AlbumPickerSheet.swift
//  SwipeClean
//
//  Modal sheet shown after a swipe-right. Displays Claude's suggested album
//  at the top, then existing albums, then "create new" option.
//
//  TODO(phase8).
//

import SwiftUI

struct AlbumPickerSheet: View {
    let suggestedAlbum: AlbumSuggestionResult?
    let existingAlbums: [String]
    let onPick: (String) -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if let suggested = suggestedAlbum {
                    Section("Claude suggests") {
                        Button {
                            onPick(suggested.name)
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text(suggested.name)
                                Spacer()
                                Text(suggested.isExisting ? "existing" : "new")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Your albums") {
                    ForEach(existingAlbums, id: \.self) { name in
                        Button(name) { onPick(name) }
                    }
                }
                Section {
                    Button("Skip filing", role: .cancel) { onSkip() }
                }
            }
            .navigationTitle("File this photo?")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
