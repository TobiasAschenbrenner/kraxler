import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Kraxler

extension KraxlerTests {
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

}
