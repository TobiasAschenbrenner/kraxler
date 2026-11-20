import SwiftUI

#if DEBUG
    extension ClimbingRoute {
        static let routeDetailFixture = ClimbingRoute(
            id: "route-detail-fixture",
            areaId: "bas-cuvier",
            name: "La Marie Rose",
            location: GeoJSONPoint(
                type: "Point",
                coordinates: [2.63823, 48.44704]
            ),
            discipline: .bouldering,
            grade: Grade(system: .fontainebleau, value: "6A", rank: 22),
            styles: [.overhang],
            lengthMeters: 5,
            pitches: 1,
            description: "A historic, slightly overhanging problem with polished holds."
        )
    }

    #Preview("Route details") {
        NavigationStack {
            RouteDetailScreen(
                routeID: ClimbingRoute.routeDetailFixture.id,
                initialRoute: .routeDetailFixture,
                loadsRemoteRoute: false
            )
        }
        .environment(AuthSession())
    }

    #Preview("Loading error") {
        NavigationStack {
            RouteDetailScreen(
                routeID: "missing-route",
                apiClient: APIClient(baseURL: URL(string: "http://localhost:1")!)
            )
        }
        .environment(AuthSession())
    }
#endif
