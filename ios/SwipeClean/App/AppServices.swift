//
//  AppServices.swift
//  SwipeClean
//
//  Shared service container. One instance per app launch, passed down through
//  the view tree so views can construct view models with consistent
//  dependencies (e.g. the QueueBuilder's Vision-pre-pass cache must outlive a
//  single deck view, which is why it lives here).
//

import Foundation
import Observation

@Observable
@MainActor
final class AppServices {

    let photoLibrary: PhotoLibraryServicing
    let claude: ClaudeServicing
    let visionPipeline: VisionPipelining
    let queueBuilder: QueueBuilding
    let store: StoreService

    init() {
        let library = PhotoLibraryService()
        let pipeline = VisionPipeline()
        self.photoLibrary = library
        self.visionPipeline = pipeline
        self.claude = ClaudeService()
        self.queueBuilder = QueueBuilder(photoLibrary: library, visionPipeline: pipeline)
        self.store = StoreService()
    }
}
