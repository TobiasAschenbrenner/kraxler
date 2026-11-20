import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Kraxler

extension KraxlerTests {
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
        let mapStore = OfflineMapStoreSpy()
        let downloadsStore = OfflineDownloadsStore(
            climbingRepository: repository,
            offlineMapStore: mapStore
        )

        await downloadsStore.download(Self.offlineArea)

        #expect(downloadsStore.operation(for: Self.offlineArea.id) == .idle)
        #expect(downloadsStore.manifest(for: Self.offlineArea.id)?.routeCount == 1)
        #expect(downloadsStore.downloadedManifests.map(\.area.id) == [Self.offlineArea.id])
        #expect(downloadsStore.isAvailableOffline(areaID: Self.offlineArea.id))
        #expect(mapStore.downloadedAreaIDsValue == [Self.offlineArea.id])

        await downloadsStore.remove(areaID: Self.offlineArea.id)

        #expect(downloadsStore.operation(for: Self.offlineArea.id) == .idle)
        #expect(downloadsStore.manifest(for: Self.offlineArea.id) == nil)
        #expect(downloadsStore.downloadedManifests.isEmpty)
        #expect(mapStore.downloadedAreaIDsValue.isEmpty)
    }

    @Test
    func reportsFailedAreaDownloads() async throws {
        let store = try makeOfflineStore()
        let repository = ClimbingRepository(
            apiClient: makeFailingClient(),
            offlineStore: store
        )
        let mapStore = OfflineMapStoreSpy()
        let downloadsStore = OfflineDownloadsStore(
            climbingRepository: repository,
            offlineMapStore: mapStore
        )

        await downloadsStore.download(Self.offlineArea)

        guard case .failed = downloadsStore.operation(for: Self.offlineArea.id) else {
            Issue.record("A failed download should publish a failure state.")
            return
        }
        #expect(downloadsStore.manifest(for: Self.offlineArea.id) == nil)
        #expect(mapStore.downloadedAreaIDsValue.isEmpty)
        #expect(mapStore.removedAreaIDs == [Self.offlineArea.id])
    }

    @Test
    func reportsMapDownloadFailuresWithoutSavingClimbingData() async throws {
        let store = try makeOfflineStore()
        let repository = ClimbingRepository(
            apiClient: makeFailingClient(),
            offlineStore: store
        )
        let mapStore = OfflineMapStoreSpy()
        mapStore.downloadError = OfflineMapStoreSpyError.downloadFailed
        let downloadsStore = OfflineDownloadsStore(
            climbingRepository: repository,
            offlineMapStore: mapStore
        )

        await downloadsStore.download(Self.offlineArea)

        guard case .failed = downloadsStore.operation(for: Self.offlineArea.id) else {
            Issue.record("A failed map download should publish a failure state.")
            return
        }
        #expect(downloadsStore.manifest(for: Self.offlineArea.id) == nil)
        #expect(!downloadsStore.isAvailableOffline(areaID: Self.offlineArea.id))
    }

    @Test
    func identifiesLegacyDataOnlyDownloadsAsIncomplete() async throws {
        let store = try makeOfflineStore()
        try store.save(area: Self.offlineArea, routes: [Self.offlineRoute])
        let repository = ClimbingRepository(
            apiClient: makeFailingClient(),
            offlineStore: store
        )
        let downloadsStore = OfflineDownloadsStore(
            climbingRepository: repository,
            offlineMapStore: OfflineMapStoreSpy()
        )

        await downloadsStore.load()

        #expect(downloadsStore.manifest(for: Self.offlineArea.id) != nil)
        #expect(downloadsStore.hasIncompleteDownload(areaID: Self.offlineArea.id))
        #expect(!downloadsStore.isAvailableOffline(areaID: Self.offlineArea.id))
    }

    @Test
    func preservesAnExistingDownloadWhenAnUpdateFails() async throws {
        let store = try makeOfflineStore()
        try store.save(area: Self.offlineArea, routes: [Self.offlineRoute])
        let repository = ClimbingRepository(
            apiClient: makeFailingClient(),
            offlineStore: store
        )
        let mapStore = OfflineMapStoreSpy(
            downloadedAreaIDs: [Self.offlineArea.id]
        )
        let downloadsStore = OfflineDownloadsStore(
            climbingRepository: repository,
            offlineMapStore: mapStore
        )
        await downloadsStore.load()

        await downloadsStore.download(Self.offlineArea)

        guard case .failed = downloadsStore.operation(for: Self.offlineArea.id) else {
            Issue.record("A failed update should publish a failure state.")
            return
        }
        #expect(downloadsStore.manifest(for: Self.offlineArea.id) != nil)
        #expect(downloadsStore.isAvailableOffline(areaID: Self.offlineArea.id))
        #expect(mapStore.removedAreaIDs.isEmpty)
    }

}
