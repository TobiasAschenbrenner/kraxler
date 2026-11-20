#if DEBUG
import Foundation
import SwiftData

enum UITestOfflineScenario {
    static func run(connectivity: ConnectivityMonitor, modelContainer: ModelContainer, topoStore: OfflineTopoStore) async {
        do {
            let api = APIClient.uiTestCapture { nil }
            let areas = try await api.areas(in: MapBounds(west: -180, south: -90, east: 180, north: 90))
            if let area = areas.first {
                let repository = ClimbingRepository(apiClient: api,
                    offlineStore: OfflineClimbingStore(modelContainer: modelContainer), topoStore: topoStore)
                try await repository.download(area)
            }
            connectivity.update(isConnected: false)
            try await Task.sleep(for: .seconds(30))
            connectivity.update(isConnected: true)
        } catch is CancellationError {
            return
        } catch {
            assertionFailure("Offline UI scenario failed: \(error)")
        }
    }
}
#endif
