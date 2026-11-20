import Foundation

nonisolated struct OfflineAreaManifest: Equatable, Identifiable, Sendable {
    static let currentDataVersion = 2

    let area: ClimbingArea
    let routeCount: Int
    let downloadedAt: Date
    let refreshedAt: Date
    let dataVersion: Int
    var topoDownloadID: String? = nil

    var id: String { area.id }
}
