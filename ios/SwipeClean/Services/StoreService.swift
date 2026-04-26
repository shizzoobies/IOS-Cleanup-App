//
//  StoreService.swift
//  SwipeClean
//
//  StoreKit 2 wrapper. Handles product loading, purchasing, entitlement
//  checks, and transaction listener. v1.0 trusts client entitlement;
//  server-side receipt validation comes in v1.1.
//

import Foundation
import StoreKit
import os.log

// MARK: - Product IDs

enum ProductID {
    static let proMonthly   = "app.swipeclean.pro.monthly"
    static let proYearly    = "app.swipeclean.pro.yearly"
    static let bigCleanup   = "app.swipeclean.bigcleanup"      // non-renewing 7-day pack

    static var all: [String] { [proMonthly, proYearly, bigCleanup] }
}

// MARK: - Entitlement

enum Entitlement: Equatable {
    case free
    case pro                    // active subscription
    case bigCleanup(until: Date) // time-limited pack
}

// MARK: - StoreService

@Observable
final class StoreService {

    var products: [Product] = []
    var entitlement: Entitlement = .free
    var isPurchasing = false
    var purchaseError: String?

    private var updateListenerTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "app.swipeclean", category: "StoreService")

    init() {
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load products

    func loadProducts() async {
        do {
            products = try await Product.products(for: ProductID.all)
                .sorted { $0.price < $1.price }
            logger.info("StoreService: loaded \(self.products.count) products")
        } catch {
            logger.error("StoreService: product load failed: \(error)")
        }
        await refreshEntitlement()
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshEntitlement()
            await transaction.finish()
            logger.info("StoreService: purchase success -- \(product.id)")

        case .userCancelled:
            logger.info("StoreService: user cancelled purchase")

        case .pending:
            logger.info("StoreService: purchase pending (Ask to Buy or payment issue)")

        @unknown default:
            break
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            logger.info("StoreService: restore complete")
        } catch {
            logger.error("StoreService: restore failed: \(error)")
            purchaseError = "Restore failed. Please try again."
        }
    }

    // MARK: - Entitlement check

    func refreshEntitlement() async {
        // Check active subscription
        for id in [ProductID.proMonthly, ProductID.proYearly] {
            if let result = await Transaction.currentEntitlement(for: id) {
                if (try? checkVerified(result)) != nil {
                    entitlement = .pro
                    logger.info("StoreService: entitlement = pro (\(id))")
                    return
                }
            }
        }

        // Check Big Cleanup pack (non-renewing -- check purchase date + 7 days)
        if let result = await Transaction.currentEntitlement(for: ProductID.bigCleanup),
           let transaction = try? checkVerified(result) {
            let expiry = transaction.purchaseDate.addingTimeInterval(7 * 24 * 3_600)
            if expiry > Date() {
                entitlement = .bigCleanup(until: expiry)
                logger.info("StoreService: entitlement = bigCleanup until \(expiry)")
                return
            }
        }

        entitlement = .free
        logger.info("StoreService: entitlement = free")
    }

    var isPro: Bool {
        switch entitlement {
        case .pro, .bigCleanup: return true
        case .free: return false
        }
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await self.refreshEntitlement()
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Verification helper

    @discardableResult
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    // MARK: - Convenience accessors

    var proMonthly: Product? { products.first { $0.id == ProductID.proMonthly } }
    var proYearly: Product?  { products.first { $0.id == ProductID.proYearly } }
    var bigCleanupPack: Product? { products.first { $0.id == ProductID.bigCleanup } }
}
