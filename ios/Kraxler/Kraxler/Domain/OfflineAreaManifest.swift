import Foundation

nonisolated struct OfflineAreaManifest: Equatable, Identifiable, Sendable {
    static let currentDataVersion = 1

    let area: ClimbingArea
    let routeCount: Int
    let downloadedAt: Date
    let refreshedAt: Date
    let dataVersion: Int

    var id: String { area.id }
}
