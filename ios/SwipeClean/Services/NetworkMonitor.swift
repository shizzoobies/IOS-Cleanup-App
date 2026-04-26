//
//  NetworkMonitor.swift
//  SwipeClean
//
//  Lightweight wrapper around NWPathMonitor for fast offline detection.
//

import Foundation
import Network

protocol NetworkMonitoring: AnyObject {
    var isReachable: Bool { get }
}

final class NetworkMonitor: NetworkMonitoring, @unchecked Sendable {

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var _isReachable: Bool = true

    var isReachable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isReachable
    }

    init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "app.swipeclean.networkmonitor")
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self._isReachable = (path.status == .satisfied)
            self.lock.unlock()
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
