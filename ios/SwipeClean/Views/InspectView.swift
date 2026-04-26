//
//  InspectView.swift
//  SwipeClean
//
//  Full-screen detail view. Pinch-to-zoom, metadata panel, AI rationale,
//  similar items carousel. Swipe left/right to act without going back.
//

import SwiftUI
import MapKit

struct InspectView: View {

    let asset: Asset
    let analysis: ClaudeAnalysis?
    let fullResImageLoader: () async -> UIImage?
    var onKeep: (() async -> Void)? = nil
    var onDelete: (() async -> Void)? = nil
    var onSkip: (() async -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var fullResImage: UIImage?
    @State private var isLoadingImage = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var selectedTab: InspectTab = .photo

    enum InspectTab: String, CaseIterable {
        case photo = "Photo"
        case info  = "Info"
        case ai    = "AI"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("View", selection: $selectedTab) {
                    ForEach(InspectTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Content
                switch selectedTab {
                case .photo: photoTab
                case .info:  infoTab
                case .ai:    aiTab
                }

                // Action buttons
                actionBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .navigationTitle("Inspect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            isLoadingImage = true
            fullResImage = await fullResImageLoader()
            isLoadingImage = false
        }
    }

    // MARK: - Photo tab

    private var photoTab: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoadingImage {
                    ProgressView()
                        .tint(.white)
                } else if let image = fullResImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(panOffset)
                        .gesture(zoomGesture)
                        .gesture(panGesture)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.35)) {
                                if scale > 1 {
                                    scale = 1
                                    panOffset = .zero
                                } else {
                                    scale = 2.5
                                }
                            }
                        }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .ignoresSafeArea(edges: .horizontal)
    }

    // MARK: - Info tab

    private var infoTab: some View {
        List {
            if let date = asset.createdAt {
                Section("Date") {
                    LabeledContent("Taken", value: date.formatted(date: .long, time: .shortened))
                }
            }

            Section("File") {
                LabeledContent("Size", value: asset.byteSize.formattedFileSize)
                if let dims = asset.dimensions {
                    LabeledContent("Dimensions", value: "\(Int(dims.width)) x \(Int(dims.height))")
                }
                if let duration = asset.durationSeconds, duration > 0 {
                    LabeledContent("Duration", value: Duration.seconds(duration).formatted(.units(allowed: [.minutes, .seconds])))
                }
                LabeledContent("Type", value: asset.type.rawValue.capitalized)
                if asset.isScreenshot {
                    LabeledContent("Screenshot", value: "Yes")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - AI tab

    private var aiTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let analysis {
                    // Category + summary
                    VStack(alignment: .leading, spacing: 8) {
                        Label(analysis.category.rawValue.capitalized, systemImage: categoryIcon(analysis.category))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(analysis.summary)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Album suggestion
                    if let album = analysis.suggestedAlbum {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Suggested Album", systemImage: "folder.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(album.name)
                                    .font(.body.weight(.medium))
                                Spacer()
                                Text(album.isExisting ? "Existing" : "New")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ConfidenceBadge(confidence: album.confidence)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Rationale
                    if let rationale = analysis.rationale {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Why this category?", systemImage: "questionmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(rationale)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                } else {
                    ContentUnavailableView(
                        "No Analysis Yet",
                        systemImage: "sparkles",
                        description: Text("AI analysis is loading or unavailable for this item.")
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 16) {
            Button {
                Task {
                    await onDelete?()
                    dismiss()
                }
            } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button {
                Task {
                    await onSkip?()
                    dismiss()
                }
            } label: {
                Label("Skip", systemImage: "arrow.right.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Button {
                Task {
                    await onKeep?()
                    dismiss()
                }
            } label: {
                Label("Keep", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    // MARK: - Gestures

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1), 5)
            }
            .onEnded { _ in
                lastScale = 1
                if scale < 1 {
                    withAnimation(.spring()) { scale = 1; panOffset = .zero }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                panOffset = CGSize(
                    width: lastPanOffset.width + value.translation.width,
                    height: lastPanOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastPanOffset = panOffset
                if scale <= 1 {
                    withAnimation(.spring()) { panOffset = .zero; lastPanOffset = .zero }
                }
            }
    }

    // MARK: - Helpers

    private func categoryIcon(_ category: AssetCategory) -> String {
        switch category {
        case .photo:       return "photo"
        case .screenshot:  return "rectangle.dashed"
        case .document:    return "doc.text"
        case .receipt:     return "receipt"
        case .meme:        return "face.smiling"
        case .social:      return "person.2"
        case .art:         return "paintbrush"
        case .nature:      return "leaf"
        case .food:        return "fork.knife"
        case .people:      return "person.fill"
        case .pet:         return "pawprint"
        case .place:       return "mappin"
        case .other:       return "square.grid.2x2"
        }
    }
}

// MARK: - Confidence badge

private struct ConfidenceBadge: View {
    let confidence: Double

    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption.weight(.semibold))
            .foregroundStyle(confidenceColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(confidenceColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private var confidenceColor: Color {
        confidence >= 0.8 ? .green : confidence >= 0.5 ? .orange : .red
    }
}

// MARK: - Int64 file size formatting

private extension Int64 {
    var formattedFileSize: String {
        let bytes = Double(self)
        if bytes < 1_024 { return "\(self) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", bytes / 1_024) }
        if bytes < 1_073_741_824 { return String(format: "%.1f MB", bytes / 1_048_576) }
        return String(format: "%.2f GB", bytes / 1_073_741_824)
    }
}
