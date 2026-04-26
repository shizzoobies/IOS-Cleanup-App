//
//  PrivacySettingsView.swift
//  SwipeClean
//
//  Privacy settings: face-aware analysis, location-aware filing, analytics opt-in.
//  Accessible from the main app via a settings sheet.
//

import SwiftUI

/// Keys shared across the app via @AppStorage.
enum PrivacyKey {
    static let faceAwareAnalysis   = "privacy.faceAwareAnalysis"
    static let locationAwareFiling = "privacy.locationAwareFiling"
    static let analyticsEnabled    = "privacy.analyticsEnabled"
}

struct PrivacySettingsView: View {

    @AppStorage(PrivacyKey.faceAwareAnalysis)   private var faceAwareAnalysis   = false
    @AppStorage(PrivacyKey.locationAwareFiling) private var locationAwareFiling = false
    @AppStorage(PrivacyKey.analyticsEnabled)    private var analyticsEnabled    = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    privacyToggle(
                        title: "Face-aware analysis",
                        description: "Allow Claude to see faces in thumbnails for richer categorization. By default, faces are blurred before any image leaves your device.",
                        icon: "person.fill.viewfinder",
                        iconColor: .orange,
                        isOn: $faceAwareAnalysis
                    )

                    privacyToggle(
                        title: "Location-aware filing",
                        description: "Include location metadata when suggesting album names (e.g., 'Paris 2024'). By default, location is stripped from all uploads.",
                        icon: "location.fill",
                        iconColor: .blue,
                        isOn: $locationAwareFiling
                    )
                } header: {
                    Text("AI analysis")
                } footer: {
                    Text("Even with these enabled, originals never leave your device. Only compressed thumbnails are sent.")
                }

                Section {
                    privacyToggle(
                        title: "Usage analytics",
                        description: "Share anonymous usage data to help improve SwipeClean. No photos, no identifiers, no personal data.",
                        icon: "chart.bar.fill",
                        iconColor: .purple,
                        isOn: $analyticsEnabled
                    )
                } header: {
                    Text("Analytics")
                } footer: {
                    Text("Off by default. Completely anonymous if enabled.")
                }

                Section("About your data") {
                    infoRow(
                        icon: "iphone",
                        iconColor: .green,
                        title: "On-device by default",
                        detail: "Duplicates, blur, screenshots detected locally."
                    )
                    infoRow(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .blue,
                        title: "No persistent storage",
                        detail: "The backend proxy is stateless. Thumbnails are never stored."
                    )
                    infoRow(
                        icon: "trash",
                        iconColor: .red,
                        title: "Deletions are reversible",
                        detail: "Photos go to Recently Deleted with a 30-day recovery window."
                    )
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Row builders

    private func privacyToggle(
        title: String,
        description: String,
        icon: String,
        iconColor: Color,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(title)
                    .font(.body.weight(.medium))

                Spacer()

                Toggle("", isOn: isOn)
                    .labelsHidden()
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func infoRow(icon: String, iconColor: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
