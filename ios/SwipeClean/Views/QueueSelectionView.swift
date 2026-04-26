//
//  QueueSelectionView.swift
//  SwipeClean
//
//  Home screen. Shows the categorized queues the user can dive into.
//

import SwiftUI

enum QueueSelectionRoute: Hashable {
    case category(QueueCategory)
    case debugAssetGrid
}

struct QueueSelectionView: View {

    let services: AppServices

    @State private var viewModel: QueueSelectionViewModel
    @State private var showPrivacySettings = false
    @State private var showPaywall = false

    init(services: AppServices) {
        self.services = services
        _viewModel = State(
            initialValue: QueueSelectionViewModel(queueBuilder: services.queueBuilder)
        )
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("What to Clean")
                .toolbar { toolbar }
                .navigationDestination(for: QueueSelectionRoute.self) { route in
                    switch route {
                    case .category(let category):
                        SwipeDeckView(
                            category: category,
                            viewModel: SwipeDeckViewModel(
                                photoLibrary: services.photoLibrary,
                                claude: services.claude
                            ),
                            services: services
                        )
                    case .debugAssetGrid:
                        DebugAssetGridView()
                    }
                }
                .sheet(isPresented: $showPrivacySettings) {
                    PrivacySettingsView()
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView(store: services.store)
                }
                .task {
                    await viewModel.load()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.summaries.isEmpty {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Scanning your library…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let message = viewModel.errorMessage, viewModel.summaries.isEmpty {
            ContentUnavailableView {
                Label("Couldn't load your library", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(QueueCategory.allCases) { category in
                        let count = viewModel.summaries.first(where: { $0.id == category })?.count ?? 0
                        NavigationLink(value: QueueSelectionRoute.category(category)) {
                            CategoryCard(category: category, count: count)
                        }
                        .buttonStyle(.plain)
                        .disabled(count == 0 && category != .surpriseMe)
                        .opacity(count == 0 && category != .surpriseMe ? 0.4 : 1.0)
                    }
                }
                .padding()
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showPrivacySettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Privacy settings")
        }
        if !services.store.isPro {
            ToolbarItem(placement: .principal) {
                Button {
                    showPaywall = true
                } label: {
                    Label("Upgrade", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(value: QueueSelectionRoute.debugAssetGrid) {
                Image(systemName: "ladybug")
            }
            .accessibilityLabel("Debug asset grid")
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
            Text("\(count) \(count == 1 ? "item" : "items")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
