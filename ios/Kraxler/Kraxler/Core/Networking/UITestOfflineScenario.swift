#if DEBUG
import Foundation
import SwiftData

enum UITestOfflineScenario {
    static func run(connectivity: ConnectivityMonitor, modelContainer: ModelContainer) async {
        do {
            let api = APIClient.uiTestCapture { nil }
            let areas = try await api.areas(in: MapBounds(west: -180, south: -90, east: 180, north: 90))
            if let area = areas.first {
                let routes = try await api.routes(for: area.id)
                try OfflineClimbingStore(modelContainer: modelContainer).save(area: area, routes: routes)
            }
            connectivity.update(isConnected: false)
            try await Task.sleep(for: .seconds(30))
            connectivity.update(isConnected: true)
        } catch {
            assertionFailure("Offline UI scenario failed: \(error)")
        }
    }
}
#endif
