import Foundation

nonisolated struct SearchResults: Codable, Equatable, Sendable {
    let areas: [ClimbingArea]
    let routes: [ClimbingRoute]

    var isEmpty: Bool {
        areas.isEmpty && routes.isEmpty
    }
}
