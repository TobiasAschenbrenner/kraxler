import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Kraxler

extension KraxlerTests {
    func makeOfflineStore() throws -> OfflineClimbingStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: OfflineAreaRecord.self,
            OfflineRouteRecord.self,
            configurations: configuration
        )
        return OfflineClimbingStore(modelContainer: container)
    }

    func makeFailingClient() -> APIClient {
        makeClient { _ in
            throw URLError(.notConnectedToInternet)
        }
    }

    func makeClient(
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

    nonisolated static func response(
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

    nonisolated static func bodyData(from request: URLRequest) -> Data? {
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

    nonisolated static let offlineArea = ClimbingArea(
        id: "area-1",
        name: "Bas Cuvier",
        type: .climbingArea,
        location: GeoJSONPoint(
            type: "Point",
            coordinates: [2.63823, 48.44704]
        )
    )

    nonisolated static let offlineRoute = ClimbingRoute(
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

@MainActor
final class AuthenticationClientSpy {
    private var account: AuthenticatedAccount?
    private var observer: AuthenticationClient.AccountObserver?
    private(set) var signOutCallCount = 0
    private(set) var appleSignInCallCount = 0
    private(set) var googleSignInCallCount = 0

    init(account: AuthenticatedAccount?) {
        self.account = account
    }

    var client: AuthenticationClient {
        AuthenticationClient(
            isConfigured: { true },
            observeAccount: { [self] observer in
                self.observer = observer
                observer(account)
                return { [weak self] in
                    self?.observer = nil
                }
            },
            signIn: { [self] email, _ in
                updateAccount(
                    AuthenticatedAccount(id: "signed-in-account", email: email)
                )
            },
            signInWithApple: { [self] _ in
                appleSignInCallCount += 1
                updateAccount(
                    AuthenticatedAccount(
                        id: "apple-account",
                        email: "climber@icloud.com"
                    )
                )
            },
            signInWithGoogle: { [self] _ in
                googleSignInCallCount += 1
                updateAccount(
                    AuthenticatedAccount(
                        id: "google-account",
                        email: "climber@gmail.com"
                    )
                )
            },
            createAccount: { [self] email, _ in
                updateAccount(
                    AuthenticatedAccount(id: "created-account", email: email)
                )
            },
            signOut: { [self] in
                signOutCallCount += 1
                updateAccount(nil)
            },
            idToken: { [self] in
                account == nil ? nil : "test-token"
            }
        )
    }

    private func updateAccount(_ account: AuthenticatedAccount?) {
        self.account = account
        observer?(account)
    }
}

enum OfflineMapStoreSpyError: Error {
    case downloadFailed
}

@MainActor
final class OfflineMapStoreSpy: OfflineMapStore {
    private(set) var downloadedAreaIDsValue: Set<String>
    private(set) var removedAreaIDs: [String] = []
    var downloadError: Error?
    var removalError: Error?

    init(downloadedAreaIDs: Set<String> = []) {
        downloadedAreaIDsValue = downloadedAreaIDs
    }

    func downloadedAreaIDs() async throws -> Set<String> {
        downloadedAreaIDsValue
    }

    func downloadMap(
        for area: ClimbingArea,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws {
        progress(0.5)
        if let downloadError {
            throw downloadError
        }
        downloadedAreaIDsValue.insert(area.id)
        progress(1)
    }

    func removeMap(for areaID: String) async throws {
        downloadedAreaIDsValue.remove(areaID)
        removedAreaIDs.append(areaID)
        if let removalError {
            throw removalError
        }
    }
}

final class URLProtocolStub: URLProtocol, @unchecked Sendable {
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

final class ThreadSafeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func incrementAndGet() -> Int {
        lock.withLock {
            count += 1
            return count
        }
    }
}
