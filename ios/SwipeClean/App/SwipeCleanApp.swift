//
//  SwipeCleanApp.swift
//  SwipeClean
//
//  App entry point. Sets up SwiftData container and root view.
//

import SwiftUI
import SwiftData

@main
struct SwipeCleanApp: App {

    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Session.self,
                Decision.self,
                CachedAnalysis.self,
                AlbumSuggestion.self
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
