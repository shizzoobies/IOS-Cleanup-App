//
//  QueueSelectionView.swift
//  SwipeClean
//
//  Home screen. Shows the categorized queues the user can dive into.
//
//  TODO(phase5): wire to real QueueSelectionViewModel.
//

import SwiftUI

struct QueueSelectionView: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(QueueCategory.allCases) { category in
                        NavigationLink(value: category) {
                            CategoryCard(category: category, count: 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("What to Clean")
            .navigationDestination(for: QueueCategory.self) { category in
                SwipeDeckView(category: category)
            }
        }
    }
}

private struct CategoryCard: View {
    let category: QueueCategory
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: category.iconSystemName)
                .font(.title)
                .foregroundStyle(.tint)
            Text(category.displayName)
                .font(.headline)
            Text("\(count) items")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
