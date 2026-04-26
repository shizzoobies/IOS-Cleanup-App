//
//  TokenStore.swift
//  SwipeClean
//
//  Stores the per-device user token in the iOS Keychain. The token is a UUID
//  generated at first launch and used as a Bearer credential for the proxy.
//

import Foundation
import Security
import os.log

protocol TokenStoring {
    func currentToken() -> String
}

final class TokenStore: TokenStoring {

    private static let logger = Logger(subsystem: "app.swipeclean", category: "TokenStore")
    private let service: String
    private let account: String

    init(service: String = "app.swipeclean.userToken", account: String = "device") {
        self.service = service
        self.account = account
    }

    func currentToken() -> String {
        if let existing = readToken() {
            return existing
        }
        let new = UUID().uuidString
        if !writeToken(new) {
            Self.logger.error("Keychain write failed; falling back to ephemeral token")
        }
        return new
    }

    private func readToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return token
    }

    private func writeToken(_ token: String) -> Bool {
        let data = Data(token.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Remove any existing entry so SecItemAdd can succeed atomically.
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        addQuery[kSecValueData as String] = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
}
