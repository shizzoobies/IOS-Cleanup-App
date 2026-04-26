//
//  DebugAssetGridView.swift
//  SwipeClean
//
//  Phase 1 sanity check. Lists asset thumbnails in a grid with a date overlay
//  and handles permission states (notDetermined, denied, limited, authorized).
//

import SwiftUI
import Photos
import PhotosUI
import os.log

@MainActor
@Observable
final class DebugAssetGridViewModel {

    enum LoadState: Equatable {
        case unknown
        case requestingPermission
        case denied
        case authorized
        case limited
    }

    private static let logger = Logger(subsystem: "app.swipeclean", category: "DebugAssetGrid")
    private static let pageSize = 200
    private static let prefetchThreshold = 50

    private let repository: AssetRepositorying

    var loadState: LoadState = .unknown
    var assets: [Asset] = []
    var totalCount: Int = 0
    var isLoadingMore: Bool = false

    var claudeTestState: ClaudeTestState = .idle
    enum ClaudeTestState: Equatable {
        case idle
        case running
        case success(category: String, summary: String, requestId: String, latencyMs: Int)
        case failure(String)
    }

    private let claude: ClaudeServicing

    init(repository: AssetRepositorying, claude: ClaudeServicing = ClaudeService()) {
        self.repository = repository
        self.claude = claude
    }

    func onAppear() async {
        let status = repository.authorizationStatus()
        switch status {
        case .authorized:
            loadState = .authorized
            await loadInitial()
        case .limited:
            loadState = .limited
            await loadInitial()
        case .denied, .restricted:
            loadState = .denied
        case .notDetermined:
            loadState = .requestingPermission
            await applyAuthorizationStatus(repository.requestAuthorization())
        @unknown default:
            loadState = .denied
        }
    }

    private func applyAuthorizationStatus(_ status: PHAuthorizationStatus) async {
        switch status {
        case .authorized:
            loadState = .authorized
            await loadInitial()
        case .limited:
            loadState = .limited
            await loadInitial()
        default:
            loadState = .denied
        }
    }

    private func loadInitial() async {
        await repository.reload()
        let total = await repository.count()
        let firstPage = await repository.page(offset: 0, limit: Self.pageSize)
        self.totalCount = total
        self.assets = firstPage
        Self.logger.log("loaded first page: \(firstPage.count, privacy: .public) of \(total, privacy: .public)")
    }

    func loadMoreIfNeeded(currentIndex: Int) async {
        guard !isLoadingMore else { return }
        guard assets.count < totalCount else { return }
        guard currentIndex >= assets.count - Self.prefetchThreshold else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let next = await repository.page(offset: assets.count, limit: Self.pageSize)
        assets.append(contentsOf: next)
    }

    func thumbnail(for asset: Asset, targetSize: CGSize) async -> UIImage? {
        await repository.thumbnail(for: asset, targetSize: targetSize)
    }

    func runClaudeAnalyzeOnFirstAsset() async {
        guard let first = assets.first else { return }
        claudeTestState = .running
        let target = CGSize(width: 1024, height: 1024)
        guard let image = await repository.thumbnail(for: first, targetSize: target) else {
            claudeTestState = .failure("Could not load thumbnail")
            return
        }
        let metadata = AnalyzeMetadata(
            assetType: first.type,
            capturedAt: first.createdAt,
            durationSeconds: first.durationSeconds,
            byteSize: first.byteSize,
            visionLabels: [],
            ocrText: nil,
            isScreenshot: first.isScreenshot,
            hasFaces: false
        )
        let started = Date()
        do {
            let result = try await claude.analyze(
                thumbnail: image,
                metadata: metadata,
                existingAlbums: [],
                suggestAlbum: false
            )
            let latencyMs = Int(Date().timeIntervalSince(started) * 1000)
            claudeTestState = .success(
                category: result.category.rawValue,
                summary: result.summary,
                requestId: result.requestId,
                latencyMs: latencyMs
            )
        } catch let error as ClaudeServiceError {
            claudeTestState = .failure(describe(error))
        } catch {
            claudeTestState = .failure(error.localizedDescription)
        }
    }

    private func describe(_ error: ClaudeServiceError) -> String {
        switch error {
        case .rateLimited(let retry): return "Rate limited; retry in \(Int(retry))s"
        case .payloadTooLarge: return "Payload too large"
        case .offline: return "Offline"
        case .invalidResponse: return "Invalid response"
        case .preprocessingFailed: return "Preprocessing failed"
        case .server(let status, let message):
            return "HTTP \(status): \(message ?? "?")"
        }
    }
}

struct DebugAssetGridView: View {

    @State private var viewModel: DebugAssetGridViewModel

    init(repository: AssetRepositorying = AssetRepository()) {
        _viewModel = State(initialValue: DebugAssetGridViewModel(repository: repository))
    }

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 2)]

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .unknown, .requestingPermission:
                ProgressView("Loading photos…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .denied:
                deniedView
            case .authorized, .limited:
                gridView
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.assets.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.runClaudeAnalyzeOnFirstAsset() }
                    } label: {
                        if case .running = viewModel.claudeTestState {
                            ProgressView()
                        } else {
                            Image(systemName: "wand.and.sparkles")
                        }
                    }
                    .disabled(viewModel.claudeTestState == .running)
                    .accessibilityLabel("Run Claude analyze")
                }
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .sheet(isPresented: claudeTestSheetBinding) {
            ClaudeTestResultSheet(state: viewModel.claudeTestState) {
                viewModel.claudeTestState = .idle
            }
            .presentationDetents([.medium])
        }
    }

    private var claudeTestSheetBinding: Binding<Bool> {
        Binding(
            get: {
                switch viewModel.claudeTestState {
                case .success, .failure: return true
                default: return false
                }
            },
            set: { newValue in
                if !newValue { viewModel.claudeTestState = .idle }
            }
        )
    }

    private var navigationTitle: String {
        viewModel.totalCount > 0 ? "Photos (\(viewModel.totalCount))" : "Photos"
    }

    private var gridView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.loadState == .limited {
                    limitedAccessBanner
                }
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(viewModel.assets.enumerated()), id: \.element.id) { index, asset in
                        AssetThumbnailCell(asset: asset) { size in
                            await viewModel.thumbnail(for: asset, targetSize: size)
                        }
                        .task(id: asset.id) {
                            await viewModel.loadMoreIfNeeded(currentIndex: index)
                        }
                    }
                }
                .padding(.horizontal, 2)
                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
                }
            }
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Photos access is required")
                .font(.headline)
            Text("Open Settings to grant SwipeClean access to your photo library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var limitedAccessBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text("Limited photo access")
                    .font(.subheadline.weight(.semibold))
                Text("Only the photos you selected are visible. Tap to manage your selection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.yellow.opacity(0.15))
        .contentShape(Rectangle())
        .onTapGesture {
            presentLimitedLibraryPicker()
        }
    }

    private func presentLimitedLibraryPicker() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            return
        }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: root)
    }
}

private struct AssetThumbnailCell: View {

    let asset: Asset
    let load: (CGSize) async -> UIImage?

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(.tertiarySystemBackground)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            VStack {
                if asset.type == .video, let duration = asset.durationSeconds {
                    HStack {
                        Spacer()
                        Text(formatDuration(duration))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(4)
                }
                Spacer()
                if let date = asset.createdAt {
                    HStack {
                        Text(date.formatted(.dateTime.month(.abbreviated).day().year(.twoDigits)))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Spacer()
                    }
                    .padding(4)
                }
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .task(id: asset.id) {
            // Roughly 3x logical points for a high-density display, capped.
            let pixelTarget = CGSize(width: 360, height: 360)
            image = await load(pixelTarget)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

private struct ClaudeTestResultSheet: View {

    let state: DebugAssetGridViewModel.ClaudeTestState
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Claude analyze test")
                    .font(.headline)
                Spacer()
                Button("Done", action: onDismiss)
            }
            switch state {
            case .success(let category, let summary, let requestId, let latencyMs):
                row(label: "Latency", value: "\(latencyMs) ms")
                row(label: "Category", value: category)
                row(label: "Summary", value: summary)
                row(label: "request_id", value: requestId, mono: true)
            case .failure(let message):
                Label("Failed", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .running, .idle:
                ProgressView()
            }
            Spacer()
        }
        .padding()
    }

    private func row(label: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(mono ? .system(.subheadline, design: .monospaced) : .subheadline)
                .textSelection(.enabled)
        }
    }
}
