import Foundation
import Testing
@testable import Kraxler

@Suite(.serialized)
@MainActor
struct LibraryStateSafetyTests {
    @Test
    func ignoresSaveConfirmationFromAnEarlierAccount() async throws {
        let store = makeStore()
        store.selectAccount("alice")
        let save = Task { try await store.update(route: Self.route, isSaved: true, isTicked: false) }
        await waitForRequests(1)
        store.selectAccount("bob")
        DeferredLibraryProtocol.complete(body: Self.savedState)
        await #expect(throws: CancellationError.self) { try await save.value }
        #expect(store.routes.isEmpty)
        #expect(store.loadState == .idle)
    }

    @Test
    func doesNotRollBackAnOldSaveIntoTheNewAccount() async throws {
        let store = makeStore()
        store.selectAccount("alice")
        let firstSave = Task { try await store.update(route: Self.route, isSaved: true, isTicked: false) }
        await waitForRequests(1)
        DeferredLibraryProtocol.complete(body: Self.savedState)
        _ = try await firstSave.value
        let remove = Task { try await store.update(route: Self.route, isSaved: false, isTicked: false) }
        await waitForRequests(1)
        store.selectAccount("bob")
        DeferredLibraryProtocol.complete(body: "{}", status: 500)
        await #expect(throws: CancellationError.self) { try await remove.value }
        #expect(store.routes.isEmpty)
        #expect(store.loadState == .idle)
    }

    @Test
    func newAccountCanLoadWhileThePreviousAccountsRequestIsPending() async throws {
        let store = makeStore()
        store.selectAccount("alice")
        let oldLoad = Task { await store.load() }
        await waitForRequests(1)
        store.selectAccount("bob")
        let newLoad = Task { await store.load() }
        await waitForRequests(2)
        DeferredLibraryProtocol.complete(body: "{\"data\":[]}", at: 1)
        await newLoad.value
        DeferredLibraryProtocol.complete(body: "{\"data\":[]}")
        await oldLoad.value
        #expect(store.loadState == .loaded)
        #expect(store.routes.isEmpty)
    }

    @Test
    func doesNotCacheRouteStateReturnedAfterReset() async throws {
        let store = makeStore()
        let read = Task { try await store.state(for: Self.route.id) }
        await waitForRequests(1)
        store.reset()
        DeferredLibraryProtocol.complete(body: Self.savedState)
        await #expect(throws: CancellationError.self) { try await read.value }
        let newRead = Task { try await store.state(for: Self.route.id) }
        await waitForRequests(1)
        DeferredLibraryProtocol.complete(body: "{\"data\":{\"routeId\":\"route-1\",\"isSaved\":false,\"isTicked\":false}}")
        #expect(try await !newRead.value.isSaved)
    }

    @Test
    func groupsDifferentSectorsByTheCanonicalAreaWithoutMergingSameNamedAreas() {
        let entries = [entry(id: "one", sector: "sector-1", parent: "cuvier"),
                       entry(id: "two", sector: "sector-2", parent: "cuvier"),
                       entry(id: "three", sector: "sector-3", parent: "another-cuvier")]
        let groups = LibraryRouteGroup.grouping(entries)
        #expect(groups.count == 2)
        #expect(groups.first(where: { $0.id == "cuvier" })?.routes.count == 2)
        #expect(groups.first(where: { $0.id == "another-cuvier" })?.routes.count == 1)
    }

    @Test
    func failedRemovalRestoresTheOriginalAreaGrouping() async throws {
        let store = makeStore()
        let save = Task {
            try await store.update(route: Self.route, areaName: "Cuvier", climbingAreaID: "parent", isSaved: true, isTicked: false)
        }
        await waitForRequests(1)
        DeferredLibraryProtocol.complete(body: Self.savedState)
        _ = try await save.value
        let remove = Task { try await store.update(route: Self.route, isSaved: false, isTicked: false) }
        await waitForRequests(1)
        DeferredLibraryProtocol.complete(body: "{}", status: 500)
        await #expect(throws: APIClientError.httpStatus(500)) { try await remove.value }
        #expect(store.routes.first?.areaName == "Cuvier")
        #expect(store.routes.first?.climbingAreaId == "parent")
    }

    @Test
    func optimisticSaveRetainsTheParentAreaIdentity() async throws {
        let store = makeStore()
        let save = Task {
            try await store.update(route: Self.route, areaName: "Cuvier", climbingAreaID: "parent", isSaved: true, isTicked: false)
        }
        await waitForRequests(1)
        #expect(store.routes.first?.climbingAreaId == "parent")
        DeferredLibraryProtocol.complete(body: Self.savedState)
        _ = try await save.value
        #expect(store.routes.first?.climbingAreaId == "parent")
    }

    private func entry(id: String, sector: String, parent: String) -> PersonalRoute {
        let route = ClimbingRoute(id: id, areaId: sector, name: id, location: Self.route.location,
            discipline: .bouldering, grade: Self.route.grade, styles: [], lengthMeters: nil, pitches: nil, description: nil)
        return PersonalRoute(route: route, areaName: "Cuvier", climbingAreaId: parent, routeId: id,
            isSaved: true, isTicked: false, tickedAt: nil)
    }

    private func makeStore() -> PersonalRoutesStore {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DeferredLibraryProtocol.self]
        return PersonalRoutesStore(apiClient: APIClient(baseURL: URL(string: "https://library-test.invalid")!,
            session: URLSession(configuration: config), authTokenProvider: { "fake-test-token" }))
    }

    private func waitForRequests(_ count: Int) async {
        for _ in 0..<100 {
            if DeferredLibraryProtocol.count == count { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Expected \(count) pending test requests")
    }

    private static let savedState = "{\"data\":{\"routeId\":\"route-1\",\"isSaved\":true,\"isTicked\":false}}"
    private static let route = ClimbingRoute(id: "route-1", areaId: "sector", name: "La Marie-Rose",
        location: GeoJSONPoint(type: "Point", coordinates: [2.63823, 48.44704]),
        discipline: .bouldering, grade: .init(system: .fontainebleau, value: "6A", rank: 22),
        styles: [], lengthMeters: 5, pitches: 1, description: nil)
}

nonisolated private final class DeferredLibraryProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var pending: [DeferredLibraryProtocol] = []
    static var count: Int { lock.withLock { pending.count } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.lock.withLock { Self.pending.append(self) } }
    override func stopLoading() {}
    static func complete(body: String, status: Int = 200, at index: Int = 0) {
        let request = lock.withLock { pending.remove(at: index) }
        let response = HTTPURLResponse(url: request.request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        request.client?.urlProtocol(request, didReceive: response, cacheStoragePolicy: .notAllowed)
        request.client?.urlProtocol(request, didLoad: Data(body.utf8))
        request.client?.urlProtocolDidFinishLoading(request)
    }
}
