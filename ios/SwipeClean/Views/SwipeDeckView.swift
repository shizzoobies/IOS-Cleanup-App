//
//  SwipeDeckView.swift
//  SwipeClean
//
//  Tinder-style swipe deck. Right=keep, left=delete, up=skip.
//  Tap card to inspect. Long-press for why-grouped panel.
//  Self-loading: builds the queue from AppServices on appear.
//

import SwiftUI
import UIKit

// MARK: - Swipe direction

private enum SwipeDirection {
    case left, right, up

    var label: String {
        switch self {
        case .left:  return "DELETE"
        case .right: return "KEEP"
        case .up:    return "SKIP"
        }
    }

    var color: Color {
        switch self {
        case .left:  return .red
        case .right: return .green
        case .up:    return .blue
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

    @Environment(AppServices.self) private var appServices
    @State private var viewModel: SwipeDeckViewModel?
    @State private var loadError: String?

    @State private var dragOffset: CGSize = .zero
    @State private var flyingOff: SwipeDirection? = nil
    @State private var showInspect = false
    @State private var showWhyGrouped = false
    @State private var showPaywall = false

    private let freeSwipeLimit = 50
    private let swipeThreshold: CGFloat = 100
    private let velocityThreshold: CGFloat = 300

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if let error = loadError {
                queueErrorView(error)
            } else if let vm = viewModel {
                if vm.isLoading {
                    deckLoadingView("Analyzing your \(category.displayName.lowercased())...")
                } else if vm.queue.isEmpty {
                    emptyState(vm: vm)
                } else {
                    deckContent(vm: vm)
                }
            } else {
                deckLoadingView("Preparing \(category.displayName.lowercased())...")
            }
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard viewModel == nil, loadError == nil else { return }
            let vm = SwipeDeckViewModel(
                photoLibrary: appServices.photoLibrary,
                claude: appServices.claude
            )
            do {
                let assets = try await appServices.queueBuilder.buildQueue(for: category)
                // Load thumbnails + first analysis before revealing the deck so
                // the user sees populated cards immediately, not a flash of "All done!".
                await vm.load(assets)
                viewModel = vm
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    // MARK: - Deck content (active queue)

    private func deckContent(vm: SwipeDeckViewModel) -> some View {
        VStack(spacing: 0) {
            progressHeader(vm: vm)
                .padding(.horizontal)
                .padding(.top, 8)

            cardStack(vm: vm)
                .frame(maxHeight: .infinity)

            actionBar(vm: vm)
                .padding(.bottom, 32)
        }
        .confirmationDialog(
            "Delete \(vm.pendingDeletions.count) photos?",
            isPresented: Binding(
                get: { vm.checkpointReached },
                set: { vm.checkpointReached = $0 }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { try? await vm.confirmBatchDeletion() }
            }
            Button("Keep in tray", role: .cancel) {
                vm.checkpointReached = false
            }
        } message: {
            Text("These photos move to Recently Deleted. You have 30 days to recover them.")
        }
        .sheet(isPresented: $showInspect) {
            if let top = vm.queue.first {
                InspectView(
                    asset: top.asset,
                    analysis: top.analysis,
                    fullResImageLoader: makeFullResLoader(for: top.asset)
                )
            }
        }
        .sheet(isPresented: $showWhyGrouped) {
            whyGroupedPanel(vm: vm)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: appServices.store)
        }
    }

    private func makeFullResLoader(for asset: Asset) -> () async -> UIImage? {
        let library = appServices.photoLibrary
        return { await library.fetchFullImage(for: asset) }
    }

    // MARK: - Card stack

    private func cardStack(vm: SwipeDeckViewModel) -> some View {
        ZStack {
            ForEach(vm.queue.prefix(3).reversed()) { card in
                let position = cardPosition(card, in: vm)
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
                .gesture(position == 0 ? dragGesture(vm: vm) : nil)
                .onTapGesture { showInspect = true }
                .onLongPressGesture { showWhyGrouped = true }
            }

            if let direction = swipeHint {
                swipeHintLabel(direction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Drag gesture

    private func dragGesture(vm: SwipeDeckViewModel) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard flyingOff == nil else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard flyingOff == nil else { return }
                let direction = committedDirection(
                    offset: value.translation,
                    velocity: value.predictedEndTranslation
                )
                if let direction {
                    commitSwipe(direction, vm: vm)
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

        if offset.height < -swipeThreshold && absY > absX  { return .up }
        if velocity.height < -velocityThreshold && absY > absX { return .up }
        if offset.width  >  swipeThreshold || velocity.width  >  velocityThreshold { return .right }
        if offset.width  < -swipeThreshold || velocity.width  < -velocityThreshold { return .left }
        return nil
    }

    private func commitSwipe(_ direction: SwipeDirection, vm: SwipeDeckViewModel) {
        guard vm.queue.first != nil else { return }

        if !appServices.store.isPro && vm.swipeCount >= freeSwipeLimit {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                dragOffset = .zero
            }
            flyingOff = nil
            showPaywall = true
            return
        }

        // Haptic feedback
        switch direction {
        case .right: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .left:  UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .up:    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        flyingOff = direction
        dragOffset = direction.flyOffset

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            Task {
                guard let topCard = vm.queue.first else { return }
                switch direction {
                case .right: await vm.handleKeep(topCard)
                case .left:  await vm.handleDelete(topCard)
                case .up:    await vm.handleSkip(topCard)
                }
                dragOffset = .zero
                flyingOff = nil
            }
        }
    }

    // MARK: - Card position helpers

    private func cardPosition(_ card: SwipeDeckViewModel.Card, in vm: SwipeDeckViewModel) -> Int {
        vm.queue.prefix(3).firstIndex(where: { $0.id == card.id }) ?? 0
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
        if dragOffset.width > 30  { return .right }
        if dragOffset.width < -30 { return .left }
        return nil
    }

    private func swipeHintLabel(_ direction: SwipeDirection) -> some View {
        let magnitude = max(abs(dragOffset.width), abs(dragOffset.height))
        let opacity = min(Double(magnitude - 30) / 70, 1)

        return Text(direction.label)
            .font(.system(size: 28, weight: .black))
            .foregroundStyle(direction.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(direction.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(direction.color, lineWidth: 3))
            .rotationEffect(
                direction == .right ? .degrees(-15) :
                direction == .left  ? .degrees(15) : .zero
            )
            .opacity(opacity)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: direction == .right ? .topLeading :
                           direction == .left  ? .topTrailing : .top
            )
            .padding(.top, 40)
            .padding(.horizontal, 40)
            .allowsHitTesting(false)
    }

    // MARK: - Progress header

    private func progressHeader(vm: SwipeDeckViewModel) -> some View {
        HStack {
            Text("\(vm.queue.count) remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if !vm.pendingDeletions.isEmpty {
                Label("\(vm.pendingDeletions.count)", systemImage: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Action bar

    private func actionBar(vm: SwipeDeckViewModel) -> some View {
        HStack(spacing: 28) {
            actionButton(systemName: "xmark", color: .red) {
                commitSwipe(.left, vm: vm)
            }
            actionButton(systemName: "arrow.uturn.backward", color: .gray) {
                Task { await vm.undo() }
            }
            actionButton(systemName: "arrow.up", color: .blue) {
                commitSwipe(.up, vm: vm)
            }
            actionButton(systemName: "checkmark", color: .green) {
                commitSwipe(.right, vm: vm)
            }
        }
    }

    private func actionButton(
        systemName: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
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

    // MARK: - Empty / loading / error states

    private func emptyState(vm: SwipeDeckViewModel) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("All done!")
                .font(.title2.weight(.semibold))
            Text("You've reviewed everything in \(category.displayName).")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !vm.pendingDeletions.isEmpty {
                Button("Delete \(vm.pendingDeletions.count) queued photos") {
                    Task { try? await vm.confirmBatchDeletion() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.top, 8)
            }
        }
        .padding(40)
    }

    private func deckLoadingView(_ message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text(message)
                .foregroundStyle(.secondary)
        }
    }

    private func queueErrorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)
            Text("Couldn't load queue")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Go Back") {
                // Navigation pops automatically via toolbar back button;
                // this is a fallback tap target for accessibility.
                loadError = nil
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
    }

    // MARK: - Why grouped panel

    private func whyGroupedPanel(vm: SwipeDeckViewModel) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if let top = vm.queue.first {
                    if let analysis = top.analysis {
                        Label("AI Analysis", systemImage: "sparkles")
                            .font(.headline)
                        Text(analysis.summary)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if top.isLoadingAnalysis {
                        HStack {
                            ProgressView()
                            Text("Analyzing...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No analysis available for this item.")
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
