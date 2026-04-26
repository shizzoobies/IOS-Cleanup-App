//
//  InspectView.swift
//  SwipeClean
//
//  Full-screen detail view for an asset. Pinch-to-zoom, metadata, similar items,
//  Claude rationale.
//
//  TODO(phase7).
//

import SwiftUI

struct InspectView: View {
    let assetId: String

    var body: some View {
        VStack {
            Text("Inspect: \(assetId)")
                .font(.headline)
            Spacer()
            Text("Full-resolution view, metadata, similar items, AI rationale go here.")
                .multilineTextAlignment(.center)
                .padding()
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
