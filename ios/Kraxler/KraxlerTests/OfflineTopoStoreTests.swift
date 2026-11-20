import Foundation
import SwiftData
import Testing
import UIKit
@testable import Kraxler

@Suite(.serialized)
@MainActor
struct OfflineTopoStoreTests {
    @Test
    func downloadsEachImageOnceAndReadsItAfterReopeningTheStores() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let manifest = try await fixture.repository.download(Self.area)
        let id = try #require(manifest.topoDownloadID)
        #expect(TopoProtocol.responses.imageRequestCount == 1)
        let reopenedImages = OfflineTopoStore(directory: fixture.directory, session: fixture.session)
        let file = try #require(reopenedImages.localURL(for: Self.imageURL, downloadID: id))
        #expect(UIImage(data: try Data(contentsOf: file)) != nil)
        let reopenedRepository = ClimbingRepository(apiClient: fixture.client,
            offlineStore: OfflineClimbingStore(modelContainer: fixture.container), topoStore: reopenedImages)
        #expect(reopenedRepository.hasDownloadedTopos(for: manifest))
        #expect(reopenedRepository.localTopoURLs(for: Self.route)["topo-1"] == file)
    }

    @Test
    func failedImageUpdateKeepsThePreviousAreaAndImages() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let original = try await fixture.repository.download(Self.area)
        let oldURL = try #require(fixture.repository.localTopoURLs(for: Self.route)["topo-1"])
        TopoProtocol.responses.failImages = true
        await #expect(throws: (any Error).self) { try await fixture.repository.download(Self.area) }
        #expect(try fixture.repository.offlineManifests().first?.topoDownloadID == original.topoDownloadID)
        #expect(FileManager.default.fileExists(atPath: oldURL.path))
        #expect(fixture.repository.hasDownloadedTopos(for: original))
        let remaining = try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path)
        #expect(remaining == [original.topoDownloadID!])
    }

    @Test
    func updatesReplaceOldImagesAndRemovalDoesNotBreakAnotherDownload() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let first = try await fixture.repository.download(Self.area)
        let firstURL = try #require(fixture.repository.localTopoURLs(for: Self.route)["topo-1"])
        let secondArea = ClimbingArea(id: "another-area", name: "Another area", type: .climbingArea, location: Self.area.location)
        let second = try await fixture.repository.download(secondArea)
        _ = try await fixture.repository.download(Self.area)
        #expect(try fixture.repository.offlineManifests().first(where: { $0.id == Self.area.id })?.topoDownloadID != first.topoDownloadID)
        #expect(!FileManager.default.fileExists(atPath: firstURL.path))
        try fixture.repository.removeDownload(for: Self.area.id)
        #expect(fixture.repository.hasDownloadedTopos(for: second))
        #expect(!fixture.repository.localTopoURLs(for: Self.route).isEmpty)
        try fixture.repository.removeDownload(for: second.id)
        #expect(fixture.repository.localTopoURLs(for: Self.route).isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path).isEmpty)
    }

    @Test
    func refusesHTMLAndDoesNotMarkAnIncompleteAreaAsDownloaded() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        TopoProtocol.responses.imageData = Data("<html>error</html>".utf8)
        await #expect(throws: OfflineTopoStore.StorageError.invalidImage) {
            try await fixture.repository.download(Self.area)
        }
        #expect(try fixture.repository.offlineManifests().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path).isEmpty)
    }

    @Test
    func missingImagesAndLegacyDownloadsAreMarkedIncomplete() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let manifest = try await fixture.repository.download(Self.area)
        let file = try #require(fixture.repository.localTopoURLs(for: Self.route)["topo-1"])
        try FileManager.default.removeItem(at: file)
        #expect(!fixture.repository.hasDownloadedTopos(for: manifest))
        let old = OfflineAreaManifest(area: Self.area, routeCount: 1, downloadedAt: .now, refreshedAt: .now, dataVersion: 1)
        #expect(!fixture.repository.hasDownloadedTopos(for: old))
    }

    @Test
    func pruningKeepsAnImagePackageThatIsStillBeingCommitted() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let id = try #require(try await fixture.images.prepareDownload(routes: [Self.route]))
        fixture.images.pruneDownloads(retaining: [])
        #expect(fixture.images.localURL(for: Self.imageURL, downloadID: id) != nil)
        fixture.images.finishDownload(id)
        fixture.images.pruneDownloads(retaining: [])
        #expect(fixture.images.localURL(for: Self.imageURL, downloadID: id) == nil)
    }

    private func makeFixture() throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory.appending(path: "topo-test-\(UUID().uuidString)")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TopoProtocol.self]
        let session = URLSession(configuration: config)
        let container = try ModelContainer(for: OfflineAreaRecord.self, OfflineRouteRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let client = APIClient(baseURL: URL(string: "https://topo-test.invalid")!, session: session)
        let images = OfflineTopoStore(directory: directory, session: session)
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        TopoProtocol.responses.configure(image: jpeg, routes: try JSONEncoder().encode(RouteResponse(data: [Self.route, Self.route])))
        return Fixture(directory: directory, container: container, client: client, session: session, images: images,
            repository: ClimbingRepository(apiClient: client, offlineStore: OfflineClimbingStore(modelContainer: container), topoStore: images))
    }

    private struct RouteResponse: Encodable { let data: [ClimbingRoute] }
    private struct Fixture {
        let directory: URL
        let container: ModelContainer
        let client: APIClient
        let session: URLSession
        let images: OfflineTopoStore
        let repository: ClimbingRepository
    }

    private static let imageURL = URL(string: "https://topo-test.invalid/topo.jpg")!
    private static let area = ClimbingArea(id: "cuvier", name: "Cuvier", type: .climbingArea,
        location: GeoJSONPoint(type: "Point", coordinates: [2.63823, 48.44704]))
    private static let route = ClimbingRoute(id: "marie-rose", areaId: "sector", name: "La Marie-Rose",
        location: area.location, discipline: .bouldering, grade: .init(system: .fontainebleau, value: "6A", rank: 22),
        styles: [], lengthMeters: 5, pitches: 1, description: nil,
        topos: [.init(id: "topo-1", imageUrl: imageURL, cloudinaryPublicId: nil, routeNumber: "1", pixelWidth: 24, pixelHeight: 24)])
}

nonisolated private final class TopoProtocol: URLProtocol, @unchecked Sendable {
    static let responses = TopoResponses()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (data, mime) = try Self.responses.response(for: request.url!)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": mime])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

nonisolated private final class TopoResponses: @unchecked Sendable {
    private let lock = NSLock()
    private var jpeg = Data()
    private var routes = Data()
    private var shouldFail = false
    private var requestCount = 0
    var failImages: Bool {
        get { lock.withLock { shouldFail } }
        set { lock.withLock { shouldFail = newValue } }
    }
    var imageData: Data {
        get { lock.withLock { jpeg } }
        set { lock.withLock { jpeg = newValue } }
    }
    var imageRequestCount: Int { lock.withLock { requestCount } }
    func configure(image: Data, routes: Data) {
        lock.withLock { jpeg = image; self.routes = routes; shouldFail = false; requestCount = 0 }
    }
    func response(for url: URL) throws -> (Data, String) {
        try lock.withLock {
            if url.path.hasSuffix("/routes") { return (routes, "application/json") }
            requestCount += 1
            if shouldFail { throw URLError(.networkConnectionLost) }
            return (jpeg, "image/jpeg")
        }
    }
}
