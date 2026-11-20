import Foundation
import Network
import Observation

@Observable
@MainActor
final class ConnectivityMonitor {
    typealias Delay = @MainActor (Duration) async throws -> Void

    private(set) var isOffline = false
    private(set) var showsOfflineIndicator = false
    private(set) var revision = 0

    @ObservationIgnored private var monitor: NWPathMonitor?
    @ObservationIgnored private var indicatorTask: Task<Void, Never>?
    @ObservationIgnored private var outageID = UUID()
    @ObservationIgnored private let delay: Delay

    init(delay: @escaping Delay = { try await Task.sleep(for: $0) }) {
        self.delay = delay
    }

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.update(isConnected: isConnected)
            }
        }
        self.monitor = monitor
        monitor.start(queue: DispatchQueue(label: "kraxler.connectivity"))
    }

    func update(isConnected: Bool) {
        // A new usable path also retries requests interrupted by a network handover.
        revision += 1
        guard isOffline == isConnected else { return }
        isOffline = !isConnected
        indicatorTask?.cancel()
        indicatorTask = nil
        showsOfflineIndicator = false
        outageID = UUID()
        guard isOffline else { return }

        let currentOutage = outageID
        let delay = delay
        indicatorTask = Task { [weak self] in
            do {
                try await delay(.seconds(10))
                guard !Task.isCancelled,
                      let self, self.isOffline, self.outageID == currentOutage else { return }
                self.showsOfflineIndicator = true
            } catch {
                // Reconnection cancels the pending indicator.
            }
        }
    }

    deinit {
        monitor?.cancel()
        indicatorTask?.cancel()
    }
}
