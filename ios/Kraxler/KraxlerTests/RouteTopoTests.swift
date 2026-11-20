import Foundation
import SwiftData
import Testing
@testable import Kraxler

struct RouteTopoTests {
    private let legacyJSON = """
    {"id":"route-1","areaId":"area-1","name":"Pegasus","location":{"type":"Point","coordinates":[10.901537,45.928681]},"discipline":"sport","grade":{"system":"french","value":"6a+","rank":11},"styles":[]}
    """

    @Test func decodesRoutesCreatedBeforeTopoSupport() throws {
        let route = try JSONDecoder().decode(ClimbingRoute.self, from: Data(legacyJSON.utf8))
        #expect(route.topos == nil)
        #expect(route.name == "Pegasus")
    }

    @Test func decodesAndRoundTripsTopoAssociations() throws {
        var json = try #require(JSONSerialization.jsonObject(with: Data(legacyJSON.utf8)) as? [String: Any])
        json["topos"] = [["id": "topo-1", "imageUrl": "https://res.cloudinary.com/demo/image/upload/topo.png", "routeNumber": "15", "pixelWidth": 427, "pixelHeight": 320]]
        let route = try JSONDecoder().decode(ClimbingRoute.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(route.topos?.first?.routeNumber == "15")
        #expect(route.topos?.first?.imageUrl.scheme == "https")
        let decoded = try JSONDecoder().decode(ClimbingRoute.self, from: JSONEncoder().encode(route))
        #expect(decoded == route)
    }

    @MainActor @Test func retainsTopoMetadataInDownloadedRouteData() throws {
        let container = try ModelContainer(
            for: OfflineAreaRecord.self, OfflineRouteRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = OfflineClimbingStore(modelContainer: container)
        let base = try JSONDecoder().decode(ClimbingRoute.self, from: Data(legacyJSON.utf8))
        let topo = ClimbingRoute.Topo(id: "topo-1", imageUrl: URL(string: "https://res.cloudinary.com/demo/image/upload/topo.png")!, cloudinaryPublicId: nil, routeNumber: "15", pixelWidth: 427, pixelHeight: 320)
        let route = ClimbingRoute(id: base.id, areaId: base.areaId, name: base.name, location: base.location, discipline: base.discipline, grade: base.grade, styles: base.styles, lengthMeters: nil, pitches: nil, description: nil, topos: [topo])
        let area = ClimbingArea(id: "area-1", name: "Massone", type: .climbingArea, location: base.location)
        try store.save(area: area, routes: [route])
        #expect(try store.route(id: route.id)?.topos == [topo])
    }
}
