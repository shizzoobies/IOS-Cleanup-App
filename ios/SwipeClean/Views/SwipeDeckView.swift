//
//  SwipeDeckView.swift
//  SwipeClean
//
//  The main swipe interaction. Tinder-style card stack with right=keep,
//  left=delete, up=skip, tap=inspect, long-press=why-grouped.
//
//  TODO(phase6): wire to real SwipeDeckViewModel and gesture handlers.
//

import SwiftUI

struct SwipeDeckView: View {
    let category: QueueCategory

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack {
                Text("Swipe deck for \(category.displayName)")
                    .font(.headline)
                Text("Right to keep · Left to delete · Up to skip · Tap to inspect")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                Spacer()
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 480)
                    .padding(.horizontal, 24)
                    .overlay {
                        Text("Card placeholder")
                            .foregroundStyle(.secondary)
                    }
                Spacer()
                HStack(spacing: 32) {
                    actionButton(systemName: "xmark", color: .red)
                    actionButton(systemName: "arrow.uturn.backward", color: .gray)
                    actionButton(systemName: "heart.fill", color: .green)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func actionButton(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(color)
            .clipShape(Circle())
    }
}
