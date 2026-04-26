//
//  RootView.swift
//  SwipeClean
//
//  Top-level routing. Decides whether to show onboarding or the main app.
//

import SwiftUI

struct RootView: View {

    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

    var body: some View {
        if didCompleteOnboarding {
            QueueSelectionView()
        } else {
            OnboardingView()
        }
    }
}
