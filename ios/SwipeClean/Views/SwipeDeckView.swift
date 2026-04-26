//
//  SwipeDeckView.swift
//  SwipeClean
//
//  Tinder-style swipe deck. Right=keep, left=delete, up=skip.
//  Tap card to inspect. Long-press for why-grouped panel.
//

import SwiftUI

// MARK: - Swipe direction

private enum SwipeDirection {
    case left, right, up

    var label: String {
        switch self {
        case .left: return "DELETE"
        case .right: return "KEEP"
        case .up: return "SKIP"
        }
    }

    var color: Color {
        switch self {
        case .left: return .red
        case .right: return .green
        case .up: return .blue
        }
    }

    var flyOffset: CGSize {
        switch self {
        case .left:  return CGSize(width: -800, height: 0)
        case .right: return CGSize(width: 800, height: 0)
        case .up:    return CGSize(width: 0, height: -800)
        }
    }
}

// MARK: - Deck view

struct SwipeDeckView: View {

    let category: QueueCategory
    @State var viewModel: SwipeDeckViewModel
    let services: AppServices

    @State private var dragOffset: CGSize = .zero
    @State private var flyingOff: SwipeDirection? = nil
    @State private var showInspect = false
    @State private var showWhyGrouped = false
    @State private var showPaywall = false
    @State private var didLoadQueue = false
    @State private var queueLoadError: String?

    private let freeSwipeLimit = 50
    private let swipeThreshold: CGFloat = 100
    private let velocityThreshold: CGFloat = 300

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if viewModel.queue.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    progressHeader
                        .padding(.horizontal)
                        .padding(.top, 8)

                    cardStack
                        .frame(maxHeight: .infinity)

                    actionBar
                        .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete \(viewModel.pendingDeletions.count) photos?",
            isPresented: $viewModel.checkpointReached,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await viewModel.confirmBatchDeletion()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } catch {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            }
            Button("Keep in tray", role: .cancel) {
                viewModel.checkpointReached = false
            }
        } message: {
            Text("These photos move to Recently Deleted. You have 30 days to recover them.")
        }
        .sheet(isPresented: $showInspect) {
            if let top = viewModel.queue.first {
                InspectView(
                    asset: top.asset,
                    analysis: top.analysis,
                    fullResImageLoader: makeFullResLoader(for: top.asset)
                )
            }
        }
        .sheet(isPresented: $showWhyGrouped) {
            whyGroupedPanel
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: services.store)
        }
        .task {
            await loadQueueIfNeeded()
        }
    }

    private func makeFullResLoader(for asset: Asset) -> () async -> UIImage? {
        let library = services.photoLibrary
        return { await library.fetchFullImage(for: asset) }
    }

    private func loadQueueIfNeeded() async {
        guard !didLoadQueue else { return }
        didLoadQueue = true
        do {
            let assets = try await services.queueBuilder.buildQueue(for: category)
            await viewModel.load(assets)
        } catch {
            queueLoadError = error.localizedDescription
        }
    }

    // MARK: - Card stack

    private var cardStack: some View {
        ZStack {
            ForEach(viewModel.queue.prefix(3).reversed()) { card in
                let position = cardPosition(for: card)
                SwipeCardView(
                    card: card,
                    dragOffset: position == 0 ? dragOffset : .zero,
                    isDragging: position == 0
                )
                .scaleEffect(cardScale(position: position))
                .offset(y: cardYOffset(position: position))
                .offset(position == 0 ? dragOffset : .zero)
                .rotationEffect(
                    position == 0 ? .degrees(Double(dragOffset.width / 20)) : .zero
                )
                .opacity(position == 0 && flyingOff != nil ? 0 : 1)
                .offset(position == 0 ? (flyingOff?.flyOffset ?? .zero) : .zero)
                .animation(
                    position == 0 && flyingOff != nil
                        ? .easeOut(duration: 0.25)
                        : .spring(response: 0.4, dampingFraction: 0.7),
                    value: flyingOff
                )
                .zIndex(Double(3 - position))
                .gesture(position == 0 ? dragGesture : nil)
                .onTapGesture { showInspect = true }
                .onLongPressGesture { showWhyGrouped = true }
            }

            // Directional hint overlays on the top card
            if let direction = swipeHint {
                swipeHintLabel(direction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Drag gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard flyingOff == nil else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard flyingOff == nil else { return }
                let velocity = value.predictedEndTranslation

                let direction = committedDirection(
                    offset: value.translation,
                    velocity: velocity
                )

                if let direction {
                    commitSwipe(direction)
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func committedDirection(offset: CGSize, velocity: CGSize) -> SwipeDirection? {
        let absX = abs(offset.width)
        let absY = abs(offset.height)

        // Up swipe takes priority when clearly vertical
        if offset.height < -swipeThreshold && absY > absX {
            return .up
        }
        if velocity.height < -velocityThreshold && absY > absX {
            return .up
        }
        if offset.width > swipeThreshold || velocity.width > velocityThreshold {
            return .right
        }
        if offset.width < -swipeThreshold || velocity.width < -velocityThreshold {
            return .left
        }
        return nil
    }

    private func commitSwipe(_ direction: SwipeDirection) {
        guard let topCard = viewModel.queue.first else { return }

        if !services.store.isPro && viewModel.swipeCount >= freeSwipeLimit {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showPaywall = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                dragOffset = .zero
            }
            flyingOff = nil
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        flyingOff = direction
        dragOffset = direction.flyOffset

        // After the fly-off animation, call the ViewModel and reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            Task {
                switch direction {
                case .right: await viewModel.handleKeep(topCard)
                case .left:  await viewModel.handleDelete(topCard)
                case .up:    await viewModel.handleSkip(topCard)
                }
                dragOffset = .zero
                flyingOff = nil
            }
        }
    }

    // MARK: - Card position helpers

    private func cardPosition(for card: SwipeDeckViewModel.Card) -> Int {
        viewModel.queue.prefix(3).firstIndex(where: { $0.id == card.id }) ?? 0
    }

    private func cardScale(position: Int) -> CGFloat {
        switch position {
        case 0: return 1.0
        case 1: return 0.95
        default: return 0.90
        }
    }

    private func cardYOffset(position: Int) -> CGFloat {
        switch position {
        case 0: return 0
        case 1: return 12
        default: return 24
        }
    }

    // MARK: - Swipe hints

    private var swipeHint: SwipeDirection? {
        let absX = abs(dragOffset.width)
        let absY = abs(dragOffset.height)
        guard max(absX, absY) > 30 else { return nil }

        if dragOffset.height < -30 && absY > absX { return .up }
        if dragOffset.width > 30 { return .right }
        if dragOffset.width < -30 { return .left }
        return nil
    }

    private func swipeHintLabel(_ direction: SwipeDirection) -> some View {
        let opacity = min(Double(max(abs(dragOffset.width), abs(dragOffset.height)) - 30) / 70, 1)

        return Text(direction.label)
            .font(.system(size: 28, weight: .black))
            .foregroundStyle(direction.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(direction.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(direction.color, lineWidth: 3))
            .rotationEffect(direction == .right ? .degrees(-15) : direction == .left ? .degrees(15) : .zero)
            .opacity(opacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: direction == .right ? .topLeading : direction == .left ? .topTrailing : .top)
            .padding(.top, 40)
            .padding(.horizontal, 40)
            .allowsHitTesting(false)
    }

    // MARK: - Progress header

    private var progressHeader: some View {
        HStack {
            Text("\(viewModel.queue.count) remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if !viewModel.pendingDeletions.isEmpty {
                Label("\(viewModel.pendingDeletions.count)", systemImage: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 28) {
            actionButton(systemName: "xmark", color: .red) {
                if let top = viewModel.queue.first { commitSwipe(.left) }
            }
            actionButton(systemName: "arrow.uturn.backward", color: .gray) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                Task { await viewModel.undo() }
            }
            actionButton(systemName: "arrow.up", color: .blue) {
                if let _ = viewModel.queue.first { commitSwipe(.up) }
            }
            actionButton(systemName: "checkmark", color: .green) {
                if let _ = viewModel.queue.first { commitSwipe(.right) }
            }
        }
    }

    private func actionButton(systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(color)
                .clipShape(Circle())
                .shadow(radius: 4, y: 2)
        }
    }

    // MARK: - Empty / loading states

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("All done!")
                .font(.title2.weight(.semibold))
            Text("You've reviewed everything in \(category.displayName).")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !viewModel.pendingDeletions.isEmpty {
                Button("Delete \(viewModel.pendingDeletions.count) queued photos") {
                    Task {
                        do {
                            try await viewModel.confirmBatchDeletion()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } catch {
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.top, 8)
            }
        }
        .padding(40)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Analyzing your \(category.displayName.lowercased())...")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Why grouped panel

    private var whyGroupedPanel: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if let top = viewModel.queue.first {
                    if let analysis = top.analysis {
                        Label("AI Analysis", systemImage: "sparkles")
                            .font(.headline)
                        Text(analysis.summary)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("No analysis available yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Why is this here?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showWhyGrouped = false }
                }
            }
        }
    }
}

// MARK: - SwipeCardView

private struct SwipeCardView: View {

    let card: SwipeDeckViewModel.Card
    let dragOffset: CGSize
    let isDragging: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Thumbnail or placeholder
            Group {
                if let image = card.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color(.tertiarySystemBackground))
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .clipped()

            // Bottom gradient + info overlay
            VStack(alignment: .leading, spacing: 6) {
                if card.isLoadingAnalysis {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("Analyzing...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                } else if let analysis = card.analysis {
                    Text(analysis.category.rawValue.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .textCase(.uppercase)
                    Text(analysis.summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if let album = analysis.suggestedAlbum {
                        Label(album.name, systemImage: "folder.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .aspectRatio(3/4, contentMode: .fit)
    }
}
