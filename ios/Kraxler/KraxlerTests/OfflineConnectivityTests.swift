import Foundation
import SwiftData
import Testing
@testable import Kraxler

@Suite(.serialized)
@MainActor
struct OfflineConnectivityTests {
    @Test
    func waitsTenContinuousSecondsAndHidesImmediatelyOnReconnection() async {
        let delay = OfflineDelayGate()
        let monitor = ConnectivityMonitor(delay: delay.wait)
        monitor.update(isConnected: false)
        await delay.waitForPendingCount(1)
        #expect(monitor.isOffline)
        #expect(!monitor.showsOfflineIndicator)
        #expect(delay.durations == [.seconds(10)])
        monitor.update(isConnected: false)
        #expect(delay.durations.count == 1)
        delay.releaseAll()
        await settle()
        #expect(monitor.showsOfflineIndicator)
        monitor.update(isConnected: true)
        #expect(!monitor.isOffline)
        #expect(!monitor.showsOfflineIndicator)
    }

    @Test
    func briefOutageAndCancelledTimerCannotShowAnIndicatorDuringANewerOutage() async {
        let delay = OfflineDelayGate()
        let monitor = ConnectivityMonitor(delay: delay.wait)
        monitor.update(isConnected: false)
        await delay.waitForPendingCount(1)
        monitor.update(isConnected: true)
        #expect(!monitor.showsOfflineIndicator)
        monitor.update(isConnected: false)
        await delay.waitForPendingCount(2)
        delay.releaseFirst()
        await settle()
        #expect(!monitor.showsOfflineIndicator)
        delay.releaseAll()
        await settle()
        #expect(monitor.showsOfflineIndicator)
        monitor.update(isConnected: true)
    }

    @Test
    func knownOfflineReadsDownloadsImmediatelyWithoutMakingRequests() async throws {
        let store = try offlineStore()
        try store.save(area: Self.area, routes: [Self.route])
        let monitor = ConnectivityMonitor()
        monitor.update(isConnected: false)
        let repository = ClimbingRepository(apiClient: failingClient(.timedOut), offlineStore: store, connectivity: monitor)
        #expect(try await repository.areas(in: Self.bounds).value == [Self.area])
        #expect(try await repository.routes(for: Self.area.id).value == [Self.route])
        #expect(try await repository.route(id: Self.route.id).value == Self.route)
        #expect(try await repository.search("Cuvier").value.areas == [Self.area])
        var filters = RouteFilters()
        filters.lengthMin = 10
        #expect(try await repository.routes(for: Self.area.id, filters: filters).value.isEmpty)
        #expect(OfflineURLProtocol.requestCount == 0)
        monitor.update(isConnected: true)
    }

    @Test
    func emptyOfflineViewportIsQuietAndMissingRouteHasASpecificOfflineState() async throws {
        let monitor = ConnectivityMonitor()
        monitor.update(isConnected: false)
        let repository = ClimbingRepository(apiClient: failingClient(.timedOut), offlineStore: try offlineStore(), connectivity: monitor)
        let model = MapScreenModel(climbingRepository: repository)
        await model.loadAreas(in: Self.bounds)
        #expect(model.loadStatus == .loaded)
        #expect(model.areas.isEmpty)
        #expect(model.contentSource == .offline)
        await #expect(throws: ClimbingRepositoryError.notAvailableOffline) {
            try await repository.route(id: "not-downloaded")
        }
        await #expect(throws: ClimbingRepositoryError.notAvailableOffline) {
            try await repository.routes(for: "not-downloaded")
        }
        #expect(OfflineURLProtocol.requestCount == 0)
        monitor.update(isConnected: true)
    }

    @Test
    func cancellationNeverFallsBackToDownloadsOrBecomesAMapError() async throws {
        let store = try offlineStore()
        try store.save(area: Self.area, routes: [Self.route])
        let repository = ClimbingRepository(apiClient: failingClient(.cancelled), offlineStore: store)
        await #expect(throws: CancellationError.self) { try await repository.areas(in: Self.bounds) }
        await #expect(throws: CancellationError.self) { try await repository.routes(for: Self.area.id) }
        await #expect(throws: CancellationError.self) { try await repository.route(id: Self.route.id) }
        await #expect(throws: CancellationError.self) { try await repository.search("Cuvier") }
        let model = MapScreenModel(climbingRepository: repository, initialAreas: [Self.area])
        await model.loadAreas(in: Self.bounds)
        #expect(model.loadStatus == .loaded)
        #expect(model.areas == [Self.area])
    }

    @Test
    func keepsVisiblePinsDuringInterruptionAndRefreshesSameBoundsAfterReconnect() async throws {
        let monitor = ConnectivityMonitor()
        let repository = ClimbingRepository(apiClient: failingClient(.networkConnectionLost), connectivity: monitor)
        let model = MapScreenModel(climbingRepository: repository, initialAreas: [Self.area])
        await model.loadAreas(in: Self.bounds)
        #expect(model.loadStatus == .loaded)
        #expect(model.areas == [Self.area])
        monitor.update(isConnected: false)
        let oldRevision = repository.connectionRevision
        await model.loadAreas(in: Self.bounds, force: true)
        #expect(model.areas == [Self.area])
        OfflineURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("{\"data\":[]}".utf8))
        }
        monitor.update(isConnected: true)
        #expect(repository.connectionRevision != oldRevision)
        await model.loadAreas(in: Self.bounds, force: true)
        #expect(model.areas.isEmpty)
        #expect(model.contentSource == .remote)
    }

    @Test
    func serverErrorDoesNotClaimTheDeviceIsOffline() async throws {
        let monitor = ConnectivityMonitor()
        let client = failingClient(.badServerResponse)
        OfflineURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
        }
        let repository = ClimbingRepository(apiClient: client, connectivity: monitor)
        let model = MapScreenModel(climbingRepository: repository)
        await model.loadAreas(in: Self.bounds)
        guard case .failed = model.loadStatus else { Issue.record("A genuine server failure should remain visible"); return }
        #expect(!monitor.isOffline)
        #expect(!monitor.showsOfflineIndicator)
        await #expect(throws: APIClientError.httpStatus(503)) { try await repository.route(id: "missing") }
    }

    private func settle() async { for _ in 0..<20 { await Task.yield() } }

    private func offlineStore() throws -> OfflineClimbingStore {
        OfflineClimbingStore(modelContainer: try ModelContainer(
            for: OfflineAreaRecord.self, OfflineRouteRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ))
    }

    private func failingClient(_ code: URLError.Code) -> APIClient {
        OfflineURLProtocol.requestCount = 0
        OfflineURLProtocol.handler = { _ in throw URLError(code) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineURLProtocol.self]
        return APIClient(baseURL: URL(string: "https://offline-test.invalid")!, session: URLSession(configuration: configuration))
    }

    private static let bounds = MapBounds(west: 2, south: 48, east: 3, north: 49)
    private static let area = ClimbingArea(id: "cuvier", name: "Cuvier", type: .climbingArea,
        location: GeoJSONPoint(type: "Point", coordinates: [2.63823, 48.44704]))
    private static let route = ClimbingRoute(id: "marie-rose", areaId: "cuvier", name: "La Marie-Rose",
        location: area.location, discipline: .bouldering,
        grade: .init(system: .fontainebleau, value: "6A", rank: 22), styles: [.overhang],
        lengthMeters: 5, pitches: 1, description: nil)
}

@MainActor
private final class OfflineDelayGate {
    private(set) var durations: [Duration] = []
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait(_ duration: Duration) async throws {
        durations.append(duration)
        await withCheckedContinuation { continuations.append($0) }
    }

    func waitForPendingCount(_ count: Int) async {
        for _ in 0..<100 {
            if continuations.count >= count { return }
            await Task.yield()
        }
        Issue.record("The delay was not scheduled")
    }

    func releaseFirst() { if !continuations.isEmpty { continuations.removeFirst().resume() } }
    func releaseAll() { while !continuations.isEmpty { releaseFirst() } }
}

nonisolated private final class OfflineURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requestCount += 1
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
