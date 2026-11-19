#if DEBUG
import Foundation

// Deterministic content for UI verification. Release builds never include this transport.
extension APIClient {
    static func uiTestCapture(authTokenProvider: @escaping AuthTokenProvider) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CaptureURLProtocol.self]
        return APIClient(session: URLSession(configuration: configuration), authTokenProvider: authTokenProvider)
    }
}

nonisolated private final class CaptureURLProtocol: URLProtocol, @unchecked Sendable {
    private static let fixtures = CaptureFixtures()

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "localhost"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let body = try Self.fixtures.response(for: request)
            let data = try JSONSerialization.data(withJSONObject: ["data": body])
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

nonisolated private final class CaptureFixtures: @unchecked Sendable {
    private let lock = NSLock()
    private var profile: [String: Any] = [
        "displayName": "Tobias Aschenbrenner", "avatarBase64": NSNull(), "usesDefaultAvatar": false,
    ]

    private let areas: [[String: Any]] = [
        ["id": "cuvier", "name": "Cuvier", "type": "climbingArea",
         "location": ["type": "Point", "coordinates": [2.63823, 48.44704]]],
        ["id": "roethelfels", "name": "Röthelfels", "type": "climbingArea",
         "location": ["type": "Point", "coordinates": [11.301, 49.79]]],
    ]

    private var routes: [[String: Any]] {
        [
            route("marie-rose", "La Marie-Rose", "6A", 22, "overhang", 5),
            route("dernier-jeu", "Le Dernier Jeu", "6A", 22, "slab", 4),
            route("scampi-fritti", "Scampi Fritti", "6C", 26, "vertical", 5),
            route("dalle-marbre", "La Dalle de Marbre", "6C+", 27, "slab", 6),
            ["id": "fight-gravity", "areaId": "roethelfels", "name": "Fight Gravity",
             "location": ["type": "Point", "coordinates": [11.301,49.79]],
             "discipline": "sport", "grade": ["system": "uiaa", "value": "7−", "rank": 14],
             "styles": ["vertical"], "lengthMeters": 24, "pitches": 1],
        ]
    }

    private func route(_ id: String, _ name: String, _ grade: String, _ rank: Int,
                       _ style: String, _ length: Int) -> [String: Any] {
        ["id": id, "areaId": "cuvier", "name": name,
         "location": ["type": "Point", "coordinates": [2.63823,48.44704]],
         "discipline": "bouldering", "grade": ["system": "fontainebleau", "value": grade, "rank": rank],
         "styles": [style], "lengthMeters": length, "pitches": 1,
         "description": "A historic, slightly overhanging problem with polished holds."]
    }

    func response(for request: URLRequest) throws -> Any {
        try lock.withLock {
            let path = request.url!.path
            if path == "/api/v1/me/profile" {
                if request.httpMethod == "PUT" {
                    var data = request.httpBody ?? Data()
                    if let stream = request.httpBodyStream {
                        stream.open()
                        defer { stream.close() }
                        var buffer = [UInt8](repeating: 0, count: 1024)
                        while stream.hasBytesAvailable {
                            let count = stream.read(&buffer, maxLength: buffer.count)
                            if count <= 0 { break }
                            data.append(contentsOf: buffer.prefix(count))
                        }
                    }
                    profile = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                }
                return profile
            }
            if path == "/api/v1/areas" { return areas }
            if path.hasSuffix("/routes"), path.contains("/areas/") {
                let areaID = String(path.split(separator: "/")[3])
                return routes.filter { ($0["areaId"] as? String) == areaID }
            }
            if path == "/api/v1/me/routes" {
                return [routes[0], routes[2], routes[4]].enumerated().map { index, route in
                    ["route": route, "routeId": route["id"]!, "isSaved": true,
                     "isTicked": index == 0, "areaName": index == 2 ? "Röthelfels" : "Cuvier"]
                }
            }
            if path.contains("/me/routes/") {
                return ["routeId": String(path.split(separator: "/").last!),
                        "isSaved": true, "isTicked": false]
            }
            if path == "/api/v1/search" {
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "q" })?.value ?? ""
                let matchingAreas = areas.filter { ($0["name"] as? String)?.localizedCaseInsensitiveContains(query) == true }
                let matchingRoutes = routes.filter { route in
                    (route["name"] as? String)?.localizedCaseInsensitiveContains(query) == true
                    || (query.lowercased() == "cuvier" && route["areaId"] as? String == "cuvier")
                }
                return ["areas": matchingAreas, "routes": matchingRoutes]
            }
            if path.contains("/api/v1/routes/"),
               let route = routes.first(where: { $0["id"] as? String == path.split(separator: "/").last.map(String.init) }) {
                return route
            }
            throw URLError(.resourceUnavailable)
        }
    }
}
#endif
