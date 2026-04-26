//
//  PaywallView.swift
//  SwipeClean
//
//  Shown when a free user hits 50 swipes. Presents Pro monthly, Pro yearly,
//  and the Big Cleanup one-time pack.
//

import SwiftUI
import StoreKit

struct PaywallView: View {

    @State var store: StoreService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("You've used your\n50 free swipes today")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("Upgrade to Pro for unlimited swipes, AI-powered album filing, and advanced duplicate grouping.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)

                    // Product cards
                    if store.products.isEmpty {
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity)
                            .padding(40)
                    } else {
                        VStack(spacing: 12) {
                            if let yearly = store.proYearly {
                                ProductCard(
                                    product: yearly,
                                    badge: "Best value",
                                    badgeColor: .green,
                                    subtitle: savingsLabel(yearly: yearly, monthly: store.proMonthly),
                                    isPurchasing: store.isPurchasing,
                                    action: { Task { try? await store.purchase(yearly) } }
                                )
                            }

                            if let monthly = store.proMonthly {
                                ProductCard(
                                    product: monthly,
                                    badge: nil,
                                    badgeColor: .blue,
                                    subtitle: "Billed monthly. Cancel any time.",
                                    isPurchasing: store.isPurchasing,
                                    action: { Task { try? await store.purchase(monthly) } }
                                )
                            }

                            if let pack = store.bigCleanupPack {
                                ProductCard(
                                    product: pack,
                                    badge: "One-time",
                                    badgeColor: .orange,
                                    subtitle: "Unlimited for 7 days. No subscription.",
                                    isPurchasing: store.isPurchasing,
                                    action: { Task { try? await store.purchase(pack) } }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Pro features list
                    VStack(alignment: .leading, spacing: 10) {
                        FeatureRow(icon: "infinity", text: "Unlimited swipes every day")
                        FeatureRow(icon: "sparkles", text: "AI album filing suggestions")
                        FeatureRow(icon: "square.stack.3d.up.fill", text: "Advanced duplicate grouping")
                        FeatureRow(icon: "doc.fill", text: "Files app integration")
                        FeatureRow(icon: "bolt.fill", text: "Priority API access")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    // Footer
                    VStack(spacing: 8) {
                        Button("Restore purchases") {
                            Task { await store.restorePurchases() }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        Text("Subscriptions auto-renew unless cancelled 24h before the renewal date. Manage in Apple ID Settings.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Go Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Maybe later") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { await store.loadProducts() }
        .onChange(of: store.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    private func savingsLabel(yearly: Product, monthly: Product?) -> String {
        guard let monthly else { return "Billed annually." }
        let annualCostOfMonthly = monthly.price * 12
        guard annualCostOfMonthly > yearly.price else { return "Billed annually." }
        let savings = annualCostOfMonthly - yearly.price
        let pct = Int((savings / annualCostOfMonthly * 100).rounded())
        return "Save \(pct)% vs monthly. Billed annually."
    }
}

// MARK: - Product card

private struct ProductCard: View {
    let product: Product
    let badge: String?
    let badgeColor: Color
    let subtitle: String
    let isPurchasing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let badge {
                            Text(badge)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(badgeColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(badgeColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(badgeColor.opacity(badge != nil ? 0.4 : 0), lineWidth: 2)
            )
        }
        .disabled(isPurchasing)
    }
}

// MARK: - Feature row

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}
