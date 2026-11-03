//
//  KraxlerTests.swift
//  KraxlerTests
//
//  Created by Tobias Aschenbrenner on 29.10.26.
//

import CoreLocation
import Foundation
import MapKit
import SwiftData
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
        #expect(personalRoutes.first?.isSaved == true)
        #expect(personalRoutes.first?.isTicked == false)
    }

    @Test
    func updatesSavedAndTickedStateTogether() async throws {
        let client = makeClient(authTokenProvider: { "firebase-id-token" }) { request in
            #expect(request.url?.path == "/api/v1/me/routes/route-1")
            #expect(request.httpMethod == "PUT")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

            let body = try #require(Self.bodyData(from: request))
            let json = try #require(
                JSONSerialization.jsonObject(with: body) as? [String: Bool]
            )
            #expect(json == ["isSaved": true, "isTicked": true])

            return Self.response(
                for: request,
                body: """
                {
                  "data": {
                    "routeId": "route-1",
                    "isSaved": true,
                    "isTicked": true,
                    "tickedAt": "2026-10-30T17:30:00.000Z"
                  }
                }
                """
            )
        }

        let state = try await client.updatePersonalRouteState(
            routeID: "route-1",
            isSaved: true,
            isTicked: true
        )

        #expect(state.isSaved)
        #expect(state.isTicked)
        #expect(state.tickedAt == "2026-10-30T17:30:00.000Z")
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

    @Test
    func storesAndReadsAnOfflineAreaPackage() throws {
        let store = try makeOfflineStore()
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        try store.save(
            area: Self.offlineArea,
            routes: [Self.offlineRoute],
            at: date
        )

        let storedManifest = try store.manifest(for: Self.offlineArea.id)
        let manifest = try #require(storedManifest)
        #expect(manifest.area == Self.offlineArea)
        #expect(manifest.routeCount == 1)
        #expect(manifest.downloadedAt == date)
        #expect(manifest.refreshedAt == date)
        #expect(try store.routes(for: Self.offlineArea.id) == [Self.offlineRoute])
        #expect(try store.route(id: Self.offlineRoute.id) == Self.offlineRoute)
    }

    @Test
    func replacesAnExistingOfflineAreaPackageOnUpdate() throws {
        let store = try makeOfflineStore()
        let downloadedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let refreshedAt = downloadedAt.addingTimeInterval(3_600)
        let replacementRoute = ClimbingRoute(
            id: "route-2",
            areaId: Self.offlineArea.id,
            name: "Le Carnage",
            location: Self.offlineRoute.location,
            discipline: .bouldering,
            grade: .init(system: .fontainebleau, value: "7B+", rank: 30),
            styles: [.overhang],
            lengthMeters: 4,
            pitches: 1,
            description: nil
        )

        try store.save(
            area: Self.offlineArea,
            routes: [Self.offlineRoute],
            at: downloadedAt
        )
        try store.save(
            area: Self.offlineArea,
            routes: [replacementRoute],
            at: refreshedAt
        )

        let storedManifest = try store.manifest(for: Self.offlineArea.id)
        let manifest = try #require(storedManifest)
        #expect(manifest.downloadedAt == downloadedAt)
        #expect(manifest.refreshedAt == refreshedAt)
        #expect(try store.routes(for: Self.offlineArea.id) == [replacementRoute])
        #expect(try store.route(id: Self.offlineRoute.id) == nil)
    }

    @Test
    func removesAnOfflineAreaAndItsRoutes() throws {
        let store = try makeOfflineStore()
        try store.save(area: Self.offlineArea, routes: [Self.offlineRoute])

        try store.remove(areaID: Self.offlineArea.id)

        #expect(try store.manifest(for: Self.offlineArea.id) == nil)
        #expect(try store.route(id: Self.offlineRoute.id) == nil)
    }

    @Test
    func searchesDownloadedAreasAndRoutes() throws {
        let store = try makeOfflineStore()
        try store.save(area: Self.offlineArea, routes: [Self.offlineRoute])

        let areaResults = try store.search("cuvier")
        let routeResults = try store.search("marie")

        #expect(areaResults.areas == [Self.offlineArea])
        #expect(areaResults.routes.isEmpty)
        #expect(routeResults.areas.isEmpty)
        #expect(routeResults.routes == [Self.offlineRoute])
    }

    @Test
    func fallsBackToDownloadedAreasWhenTheAPIIsUnavailable() async throws {
        let store = try makeOfflineStore()
        try store.save(area: Self.offlineArea, routes: [Self.offlineRoute])
        let repository = ClimbingRepository(
            apiClient: makeFailingClient(),
            offlineStore: store
        )

        let response = try await repository.areas(
            in: MapBounds(west: 2.5, south: 48.4, east: 2.7, north: 48.5)
        )

        #expect(response.source == .offline)
        #expect(response.value == [Self.offlineArea])
    }

    @Test
    func filtersDownloadedRoutesWhenTheAPIIsUnavailable() async throws {
        let store = try makeOfflineStore()
        try store.save(area: Self.offlineArea, routes: [Self.offlineRoute])
        let repository = ClimbingRepository(
            apiClient: makeFailingClient(),
            offlineStore: store
        )

        let matchingResponse = try await repository.routes(
            for: Self.offlineArea.id,
            filters: RouteFilters(
                discipline: .bouldering,
                gradeSystem: .fontainebleau,
                gradeMin: "5C",
                gradeMax: "6B",
                styles: [.overhang],
                lengthMin: 4,
                lengthMax: 6,
                pitchesMin: 1,
                pitchesMax: 1
            )
        )
        let excludedResponse = try await repository.routes(
            for: Self.offlineArea.id,
            filters: RouteFilters(styles: [.slab])
        )

        #expect(matchingResponse.source == .offline)
        #expect(matchingResponse.value == [Self.offlineRoute])
        #expect(excludedResponse.value.isEmpty)
    }

    @Test
    func searchesDownloadedContentWhenTheAPIIsUnavailable() async throws {
        let store = try makeOfflineStore()
        try store.save(area: Self.offlineArea, routes: [Self.offlineRoute])
        let repository = ClimbingRepository(
            apiClient: makeFailingClient(),
            offlineStore: store
        )

        let response = try await repository.search("Marie")

        #expect(response.source == .offline)
        #expect(response.value.routes == [Self.offlineRoute])
    }

    @Test
    func downloadsAnAreaPackageFromTheAPI() async throws {
        let store = try makeOfflineStore()
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
                    "pitches": 1,
                    "description": "A historic Fontainebleau problem."
                  }],
                  "meta": { "count": 1 }
                }
                """
            )
        }
        let repository = ClimbingRepository(apiClient: client, offlineStore: store)

        let manifest = try await repository.download(Self.offlineArea)

        #expect(manifest.area == Self.offlineArea)
        #expect(manifest.routeCount == 1)
        #expect(try store.route(id: Self.offlineRoute.id) == Self.offlineRoute)
    }

    @Test
    func managesDownloadAndRemovalState() async throws {
        let store = try makeOfflineStore()
        let client = makeClient { request in
            Self.response(
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
                    "styles": ["overhang"]
                  }],
                  "meta": { "count": 1 }
                }
                """
            )
        }
        let repository = ClimbingRepository(apiClient: client, offlineStore: store)
        let downloadsStore = OfflineDownloadsStore(climbingRepository: repository)

        await downloadsStore.download(Self.offlineArea)

        #expect(downloadsStore.operation(for: Self.offlineArea.id) == .idle)
        #expect(downloadsStore.manifest(for: Self.offlineArea.id)?.routeCount == 1)

        downloadsStore.remove(areaID: Self.offlineArea.id)

        #expect(downloadsStore.operation(for: Self.offlineArea.id) == .idle)
        #expect(downloadsStore.manifest(for: Self.offlineArea.id) == nil)
    }

    @Test
    func reportsFailedAreaDownloads() async throws {
        let store = try makeOfflineStore()
        let repository = ClimbingRepository(
            apiClient: makeFailingClient(),
            offlineStore: store
        )
        let downloadsStore = OfflineDownloadsStore(climbingRepository: repository)

        await downloadsStore.download(Self.offlineArea)

        guard case .failed = downloadsStore.operation(for: Self.offlineArea.id) else {
            Issue.record("A failed download should publish a failure state.")
            return
        }
        #expect(downloadsStore.manifest(for: Self.offlineArea.id) == nil)
    }

    private func makeOfflineStore() throws -> OfflineClimbingStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: OfflineAreaRecord.self,
            OfflineRouteRecord.self,
            configurations: configuration
        )
        return OfflineClimbingStore(modelContainer: container)
    }

    private func makeFailingClient() -> APIClient {
        makeClient { _ in
            throw URLError(.notConnectedToInternet)
        }
    }

    private func makeClient(
        authTokenProvider: @escaping APIClient.AuthTokenProvider = { nil },
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        URLProtocolStub.handler = handler

        return APIClient(
            baseURL: URL(string: "http://localhost:3000")!,
            session: URLSession(configuration: configuration),
            authTokenProvider: authTokenProvider
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

    nonisolated private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)

            if bytesRead < 0 {
                return nil
            }

            if bytesRead == 0 {
                return data.isEmpty ? nil : data
            }

            data.append(buffer, count: bytesRead)
        }
    }

    nonisolated private static let offlineArea = ClimbingArea(
        id: "area-1",
        name: "Bas Cuvier",
        type: .climbingArea,
        location: GeoJSONPoint(
            type: "Point",
            coordinates: [2.63823, 48.44704]
        )
    )

    nonisolated private static let offlineRoute = ClimbingRoute(
        id: "route-1",
        areaId: "area-1",
        name: "La Marie Rose",
        location: GeoJSONPoint(
            type: "Point",
            coordinates: [2.63823, 48.44704]
        ),
        discipline: .bouldering,
        grade: .init(system: .fontainebleau, value: "6A", rank: 22),
        styles: [.overhang],
        lengthMeters: 5,
        pitches: 1,
        description: "A historic Fontainebleau problem."
    )
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
