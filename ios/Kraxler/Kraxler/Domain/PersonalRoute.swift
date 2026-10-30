import Foundation

nonisolated struct PersonalRouteState: Codable, Equatable, Sendable {
    let routeId: String
    let isSaved: Bool
    let isTicked: Bool
    let tickedAt: String?

    static func empty(routeID: String) -> PersonalRouteState {
        PersonalRouteState(
            routeId: routeID,
            isSaved: false,
            isTicked: false,
            tickedAt: nil
        )
    }
}

nonisolated struct PersonalRoute: Codable, Identifiable, Sendable {
    let route: ClimbingRoute
    let routeId: String
    let isSaved: Bool
    let isTicked: Bool
    let tickedAt: String?

    var id: String { routeId }

    var state: PersonalRouteState {
        PersonalRouteState(
            routeId: routeId,
            isSaved: isSaved,
            isTicked: isTicked,
            tickedAt: tickedAt
        )
    }
}
