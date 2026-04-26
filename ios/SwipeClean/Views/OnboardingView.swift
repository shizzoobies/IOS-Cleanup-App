//
//  OnboardingView.swift
//  SwipeClean
//
//  4-screen onboarding: welcome, privacy explainer, permissions, ready.
//  Requests Photos authorization on the permissions screen.
//

import SwiftUI
import Photos

struct OnboardingView: View {

    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @State private var currentPage = 0
    @State private var photoAuthStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomePage(onNext: { currentPage = 1 })
                .tag(0)
            PrivacyPage(onNext: { currentPage = 2 })
                .tag(1)
            PermissionsPage(
                authStatus: $photoAuthStatus,
                onNext: { currentPage = 3 }
            )
            .tag(2)
            ReadyPage(onFinish: { didCompleteOnboarding = true })
                .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut, value: currentPage)
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingPageLayout(
            icon: "sparkles.rectangle.stack.fill",
            iconColor: .blue,
            title: "SwipeClean",
            subtitle: "Swipe right to keep. Swipe left to delete. Claude does the thinking so you can move fast.",
            primaryButton: ("Get Started", onNext),
            secondaryButton: nil
        )
    }
}

// MARK: - Page 2: Privacy explainer

private struct PrivacyPage: View {
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    Text("Your privacy comes first")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                VStack(spacing: 16) {
                    PrivacyTierRow(
                        icon: "iphone",
                        iconColor: .blue,
                        title: "On-device analysis",
                        description: "Duplicate detection, blur detection, and basic sorting happen entirely on your phone. Nothing leaves the device."
                    )
                    PrivacyTierRow(
                        icon: "photo.badge.arrow.down",
                        iconColor: .orange,
                        title: "Thumbnails only",
                        description: "For AI categorization, SwipeClean sends a small thumbnail -- max 512px, faces blurred by default, location stripped. Originals never leave your phone."
                    )
                    PrivacyTierRow(
                        icon: "hand.raised.fill",
                        iconColor: .purple,
                        title: "You control the rest",
                        description: "Face-aware analysis and location-aware filing are opt-in only. You can change these any time in Settings."
                    )
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)

                OnboardingButton("Continue", action: onNext)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 80)
            }
        }
    }
}

private struct PrivacyTierRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Page 3: Permissions

private struct PermissionsPage: View {
    @Binding var authStatus: PHAuthorizationStatus
    let onNext: () -> Void

    var body: some View {
        OnboardingPageLayout(
            icon: authStatus == .authorized || authStatus == .limited
                ? "checkmark.circle.fill" : "photo.on.rectangle.angled",
            iconColor: authStatus == .authorized || authStatus == .limited ? .green : .blue,
            title: "Allow photo access",
            subtitle: "SwipeClean needs access to your photo library to show you what to keep and what to delete.",
            primaryButton: (primaryButtonLabel, primaryButtonAction),
            secondaryButton: authStatus == .denied || authStatus == .restricted
                ? ("Open Settings", openSettings) : nil
        )
    }

    private var primaryButtonLabel: String {
        switch authStatus {
        case .authorized, .limited: return "Continue"
        case .denied, .restricted:  return "Access Denied"
        default:                    return "Allow Photos Access"
        }
    }

    private var primaryButtonAction: () -> Void {
        switch authStatus {
        case .authorized, .limited:
            return onNext
        case .denied, .restricted:
            return { }
        default:
            return requestPermission
        }
    }

    private func requestPermission() {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run { authStatus = status }
            if status == .authorized || status == .limited {
                onNext()
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Page 4: Ready

private struct ReadyPage: View {
    let onFinish: () -> Void

    var body: some View {
        OnboardingPageLayout(
            icon: "hands.sparkles.fill",
            iconColor: .green,
            title: "You're all set",
            subtitle: "SwipeClean will analyze your photos and group them into categories. Start with duplicates, or let us surprise you.",
            primaryButton: ("Start Cleaning", onFinish),
            secondaryButton: nil
        )
    }
}

// MARK: - Shared layout

private struct OnboardingPageLayout: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let primaryButton: (String, () -> Void)
    let secondaryButton: (String, () -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 72))
                    .foregroundStyle(iconColor)
                    .padding(.bottom, 8)

                Text(title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                OnboardingButton(primaryButton.0, action: primaryButton.1)

                if let secondary = secondaryButton {
                    Button(secondary.0, action: secondary.1)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 80)
        }
    }
}

private struct OnboardingButton: View {
    let label: String
    let action: () -> Void

    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
    }
}
