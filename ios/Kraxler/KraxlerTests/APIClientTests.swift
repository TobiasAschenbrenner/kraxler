import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Kraxler

extension KraxlerTests {
    @Test
    func fetchesAreasInsideMapBounds() async throws {
        let client = makeClient { request in
            #expect(request.url?.path == "/api/v1/areas")
            #expect(request.url?.query == "bbox=2.4,48.3,2.8,48.6")

            return Self.response(
                for: request,
                body: """
                {
                  "data": [{
                    "id": "area-1",
                    "name": "Bas Cuvier",
                    "type": "climbingArea",
                    "location": { "type": "Point", "coordinates": [2.63823, 48.44704] }
                  }],
                  "meta": { "count": 1 }
                }
                """
            )
        }

        let areas = try await client.areas(
            in: MapBounds(west: 2.4, south: 48.3, east: 2.8, north: 48.6)
        )

        #expect(areas.count == 1)
        #expect(areas.first?.name == "Bas Cuvier")
        #expect(areas.first?.location.coordinate.latitude == 48.44704)
        #expect(areas.first?.location.coordinate.longitude == 2.63823)
    }

    @Test
    func fetchesRoutesForSelectedArea() async throws {
        let client = makeClient { request in
            #expect(request.url?.path == "/api/v1/areas/area-1/routes")

            return Self.response(
                for: request,
                body: """
                {
                  "data": [{
                    "id": "route-1",
                    "areaId": "area-1",
                    "name": "La Marie Rose",
                    "location": { "type": "Point", "coordinates": [2.63823, 48.44704] },
                    "discipline": "bouldering",
                    "grade": { "system": "fontainebleau", "value": "6A", "rank": 22 },
                    "styles": ["overhang"],
                    "lengthMeters": 5,
                    "pitches": 1
                  }],
                  "meta": { "count": 1 }
                }
                """
            )
        }

        let routes = try await client.routes(for: "area-1")

        #expect(routes.count == 1)
        #expect(routes.first?.grade.value == "6A")
        #expect(routes.first?.styles == [.overhang])
        #expect(routes.first?.lengthMeters == 5)
    }

    @Test
    func sendsSelectedRouteFilters() async throws {
        let client = makeClient { request in
            #expect(request.url?.path == "/api/v1/areas/area-1/routes")
            let queryItems = URLComponents(
                url: request.url!,
                resolvingAgainstBaseURL: false
            )?.queryItems
            #expect(
                queryItems == [
                    URLQueryItem(name: "discipline", value: "sport"),
                    URLQueryItem(name: "gradeSystem", value: "uiaa"),
                    URLQueryItem(name: "gradeMin", value: "6"),
                    URLQueryItem(name: "gradeMax", value: "8+"),
                    URLQueryItem(name: "style", value: "crack,vertical"),
                    URLQueryItem(name: "lengthMin", value: "15"),
                    URLQueryItem(name: "lengthMax", value: "30"),
                    URLQueryItem(name: "pitchesMin", value: "1"),
                    URLQueryItem(name: "pitchesMax", value: "2"),
                ]
            )

            return Self.response(
                for: request,
                body: """
                { "data": [], "meta": { "count": 0 } }
                """
            )
        }

        let routes = try await client.routes(
            for: "area-1",
            filters: RouteFilters(
                discipline: .sport,
                gradeSystem: .uiaa,
                gradeMin: "6",
                gradeMax: "8+",
                styles: [.vertical, .crack],
                lengthMin: 15,
                lengthMax: 30,
                pitchesMin: 1,
                pitchesMax: 2
            )
        )

        #expect(routes.isEmpty)
    }

    @Test
    func fetchesCompleteRouteDetails() async throws {
        let client = makeClient { request in
            #expect(request.url?.path == "/api/v1/routes/route-1")

            return Self.response(
                for: request,
                body: """
                {
                  "data": {
                    "id": "route-1",
                    "areaId": "area-1",
                    "name": "La Marie Rose",
                    "location": { "type": "Point", "coordinates": [2.63823, 48.44704] },
                    "discipline": "bouldering",
                    "grade": { "system": "fontainebleau", "value": "6A", "rank": 22 },
                    "styles": ["overhang"],
                    "lengthMeters": 5,
                    "pitches": 1,
                    "description": "A historic Fontainebleau problem."
                  }
                }
                """
            )
        }

        let route = try await client.route(id: "route-1")

        #expect(route.name == "La Marie Rose")
        #expect(route.grade.value == "6A")
        #expect(route.discipline == .bouldering)
        #expect(route.styles == [.overhang])
        #expect(route.lengthMeters == 5)
        #expect(route.pitches == 1)
        #expect(route.description == "A historic Fontainebleau problem.")
        #expect(route.location.coordinate.latitude == 48.44704)
        #expect(route.location.coordinate.longitude == 2.63823)
    }

    @Test
    func searchesAreasAndRoutesGlobally() async throws {
        let client = makeClient { request in
            #expect(request.url?.path == "/api/v1/search")
            let queryItems = URLComponents(
                url: request.url!,
                resolvingAgainstBaseURL: false
            )?.queryItems
            #expect(queryItems == [URLQueryItem(name: "q", value: "Marie Rose")])

            return Self.response(
                for: request,
                body: """
                {
                  "data": {
                    "areas": [{
                      "id": "area-1",
                      "name": "Cuvier",
                      "type": "climbingArea",
                      "location": { "type": "Point", "coordinates": [2.63823, 48.44704] }
                    }],
                    "routes": [{
                      "id": "route-1",
                      "areaId": "area-1",
                      "name": "La Marie Rose",
                      "location": { "type": "Point", "coordinates": [2.63823, 48.44704] },
                      "discipline": "bouldering",
                      "grade": { "system": "fontainebleau", "value": "6A", "rank": 22 },
                      "styles": ["overhang"]
                    }]
                  },
                  "meta": { "areaCount": 1, "routeCount": 1 }
                }
                """
            )
        }

        let results = try await client.search("Marie Rose")

        #expect(results.areas.map(\.name) == ["Cuvier"])
        #expect(results.routes.map(\.name) == ["La Marie Rose"])
    }

    @Test
    func fetchesAuthenticatedPersonalRoutes() async throws {
        let client = makeClient(authTokenProvider: { "firebase-id-token" }) { request in
            #expect(request.url?.path == "/api/v1/me/routes")
            #expect(request.httpMethod == "GET")
            #expect(
                request.value(forHTTPHeaderField: "Authorization") ==
                    "Bearer firebase-id-token"
            )

            return Self.response(
                for: request,
                body: """
                {
                  "data": [{
                    "route": {
                      "id": "route-1",
                      "areaId": "area-1",
                      "name": "La Marie Rose",
                      "location": { "type": "Point", "coordinates": [2.63823, 48.44704] },
                      "discipline": "bouldering",
                      "grade": { "system": "fontainebleau", "value": "6A", "rank": 22 },
                      "styles": ["overhang"]
                    },
                    "areaName": "Bas Cuvier",
                    "routeId": "route-1",
                    "isSaved": true,
                    "isTicked": false
                  }],
                  "meta": { "count": 1 }
                }
                """
            )
        }

        let personalRoutes = try await client.personalRoutes()

        #expect(personalRoutes.map(\.route.name) == ["La Marie Rose"])
        #expect(personalRoutes.first?.areaName == "Bas Cuvier")
        #expect(personalRoutes.first?.isSaved == true)
        #expect(personalRoutes.first?.isTicked == false)
    }

    @Test
    func requiresAuthenticationForPersonalRoutes() async {
        let client = makeClient { request in
            Issue.record("An unauthenticated personal route request should not be sent: \(request)")
            return Self.response(for: request, body: "{}")
        }

        await #expect(throws: APIClientError.authenticationRequired) {
            try await client.personalRoutes()
        }
    }

    @Test
    func reportsHTTPFailures() async {
        let client = makeClient { request in
            (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data()
            )
        }

        await #expect(throws: APIClientError.httpStatus(503)) {
            try await client.routes(for: "area-1")
        }
    }

}
