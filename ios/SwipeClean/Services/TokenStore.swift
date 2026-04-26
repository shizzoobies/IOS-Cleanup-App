//
//  TokenStore.swift
//  SwipeClean
//
//  Stores the per-device user token in the iOS Keychain. The token is a UUID
//  generated at first launch and used for backend rate limiting.
//
//  TODO(phase4): replace stub with real Keychain Services calls.
//

import Foundation

protocol TokenStoring {
    func currentToken() -> String
}

final class TokenStore: TokenStoring {

    private let key = "app.swipeclean.userToken"

    func currentToken() -> String {
        // TODO(phase4): real Keychain read/write. UserDefaults is a placeholder for skeleton.
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}
