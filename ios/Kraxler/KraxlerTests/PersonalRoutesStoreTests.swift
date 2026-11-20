import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Kraxler

extension KraxlerTests {
    @Test
    func keepsLoadedPersonalRoutesVisibleWhenRefreshFails() async {
        let requests = ThreadSafeCounter()
        let client = makeClient(authTokenProvider: { "firebase-id-token" }) { request in
            guard requests.incrementAndGet() == 1 else {
                throw URLError(.cannotLoadFromNetwork)
            }

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
        let store = PersonalRoutesStore(apiClient: client)

        await store.load()
        await store.load(force: true)

        #expect(store.loadState == .loaded)
        #expect(store.routes.map(\.route.name) == ["La Marie Rose"])
        #expect(requests.value == 2)
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

}
