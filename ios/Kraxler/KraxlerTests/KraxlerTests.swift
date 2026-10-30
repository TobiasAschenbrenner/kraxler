//
//  KraxlerTests.swift
//  KraxlerTests
//
//  Created by Tobias Aschenbrenner on 29.10.26.
//

import CoreLocation
import Foundation
import MapKit
import Testing
@testable import Kraxler

@Suite(.serialized)
@MainActor
struct KraxlerTests {
    @Test
    func derivesBoundsFromVisibleMapRegion() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.5, longitude: 3),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 1)
        )

        let bounds = MapBounds(region: region)

        #expect(bounds.west == 2.5)
        #expect(bounds.south == 48.25)
        #expect(bounds.east == 3.5)
        #expect(bounds.north == 48.75)
    }

    @Test
    func collapsesOverlappingHierarchyIntoOneClimbingAreaMarker() {
        let location = GeoJSONPoint(
            type: "Point",
            coordinates: [2.63823, 48.44704]
        )
        let region = ClimbingArea(
            id: "fontainebleau",
            name: "Fontainebleau",
            type: .region,
            location: location
        )
        let climbingArea = ClimbingArea(
            id: "cuvier",
            name: "Cuvier",
            type: .climbingArea,
            location: location
        )
        let sector = ClimbingArea(
            id: "bas-cuvier",
            name: "Bas Cuvier",
            type: .sector,
            location: location
        )
        let model = MapScreenModel(
            apiClient: APIClient(),
            initialAreas: [region, sector, climbingArea]
        )

        #expect(model.visibleAreas == [climbingArea])
    }

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

    private func makeClient(
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        URLProtocolStub.handler = handler

        return APIClient(
            baseURL: URL(string: "http://localhost:3000")!,
            session: URLSession(configuration: configuration)
        )
    }

    nonisolated private static func response(
        for request: URLRequest,
        body: String
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            Data(body.utf8)
        )
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("URLProtocolStub.handler must be configured before a test runs.")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
