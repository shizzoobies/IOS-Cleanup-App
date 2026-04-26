//
//  OnboardingView.swift
//  SwipeClean
//
//  TODO(phase10): real onboarding with privacy explainer and permission prompts.
//

import SwiftUI

struct OnboardingView: View {

    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            Text("SwipeClean")
                .font(.largeTitle.bold())
            Text("Tinder for your camera roll. Swipe right to keep, left to delete. Claude helps you file what's worth keeping.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                didCompleteOnboarding = true
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}
