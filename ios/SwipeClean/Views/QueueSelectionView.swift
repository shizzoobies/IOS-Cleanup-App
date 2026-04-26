//
//  QueueSelectionView.swift
//  SwipeClean
//
//  Home screen. Shows the categorized queues the user can dive into.
//  Wired to QueueSelectionViewModel via AppServices environment injection.
//

import SwiftUI

struct QueueSelectionView: View {

    @Environment(AppServices.self) private var appServices
    @State private var viewModel: QueueSelectionViewModel?
    @State private var showPrivacy = false
    @State private var showPaywall = false
    @State private var showDebugGrid = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("What to Clean")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { toolbar }
                .navigationDestination(for: QueueCategory.self) { category in
                    SwipeDeckView(category: category)
                }
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacySettingsView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: appServices.store)
        }
        .sheet(isPresented: $showDebugGrid) {
            NavigationStack {
                DebugAssetGridView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showDebugGrid = false }
                        }
                    }
            }
        }
        .task {
            guard viewModel == nil else { return }
            let vm = QueueSelectionViewModel(queueBuilder: appServices.queueBuilder)
            viewModel = vm
            await vm.load()
        }
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        if let vm = viewModel {
            if vm.isLoading {
                loadingView(message: "Analyzing your library...")
            } else if let error = vm.errorMessage {
                errorView(message: error, vm: vm)
            } else if vm.summaries.isEmpty {
                emptyLibraryView
            } else {
                categoriesGrid(vm: vm)
            }
        } else {
            loadingView(message: "Loading...")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showPrivacy = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Privacy settings")
        }
        if !appServices.store.isPro {
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
            Button {
                showDebugGrid = true
            } label: {
                Image(systemName: "ladybug")
            }
            .accessibilityLabel("Debug asset grid")
        }
    }

    // MARK: - Loading state

    private func loadingView(message: String) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error state

    private func errorView(message: String, vm: QueueSelectionViewModel) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)

            Text("Could not load library")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                Task {
                    vm.errorMessage = nil
                    await vm.load()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty library state

    private var emptyLibraryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Your library looks great!")
                .font(.title3.weight(.semibold))
            Text("No obvious clutter found. Check back after adding more photos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main grid

    private func categoriesGrid(vm: QueueSelectionViewModel) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 16
            ) {
                ForEach(vm.summaries) { summary in
                    NavigationLink(value: summary.category) {
                        CategoryCard(
                            category: summary.category,
                            count: summary.count
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            filesCard
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 24)
        }
        .refreshable {
            await vm.load()
        }
    }

    // MARK: - Files card

    private var filesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Files App")
                .font(.headline)
                .padding(.leading, 4)

            Button {
                // TODO(scope): push FilesQueueView when implemented
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .frame(width: 48, height: 48)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Clean up Files")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Swipe through downloads, PDFs, and documents")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Category card

private struct CategoryCard: View {
    let category: QueueCategory
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: category.iconSystemName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(category.cardColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer(minLength: 0)

            Text(category.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(count == 1 ? "1 item" : "\(count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(category.cardColor.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - QueueCategory color

private extension QueueCategory {
    var cardColor: Color {
        switch self {
        case .duplicates:          return .purple
        case .screenshots:         return .blue
        case .blurry:              return .gray
        case .largeFiles:          return .red
        case .oldUntouched:        return .brown
        case .receiptsAndDocuments: return .teal
        case .everythingElse:      return .indigo
        case .surpriseMe:          return .pink
        }
    }
}
