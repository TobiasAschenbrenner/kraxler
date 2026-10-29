import Foundation

nonisolated struct ClimbingArea: Codable, Hashable, Identifiable, Sendable {
    enum AreaType: String, Codable, Sendable {
        case region
        case climbingArea
        case sector
    }

    let id: String
    let name: String
    let type: AreaType
    let location: GeoJSONPoint
}
