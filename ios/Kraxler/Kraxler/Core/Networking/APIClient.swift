import Foundation

nonisolated struct MapBounds: Equatable, Hashable, Sendable {
    let west: Double
    let south: Double
    let east: Double
    let north: Double

    var queryValue: String {
        [west, south, east, north]
            .map { String($0) }
            .joined(separator: ",")
    }
}

nonisolated enum APIClientError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case authenticationRequired
    case httpStatus(Int)
}

nonisolated struct APIClient: Sendable {
    typealias AuthTokenProvider = @MainActor @Sendable () async throws -> String?

    private struct ListResponse<Value: Decodable & Sendable>: Decodable, Sendable {
        let data: [Value]
    }

    private struct ItemResponse<Value: Decodable & Sendable>: Decodable, Sendable {
        let data: Value
    }

    private struct SearchResponse: Decodable, Sendable {
        let data: SearchResults
    }

    private struct PersonalRouteUpdate: Encodable, Sendable {
        let isSaved: Bool
        let isTicked: Bool
    }

    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let authTokenProvider: AuthTokenProvider

    init(
        baseURL: URL = URL(string: "http://localhost:3000")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        authTokenProvider: @escaping AuthTokenProvider = { nil }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.authTokenProvider = authTokenProvider
    }

    func areas(in bounds: MapBounds) async throws -> [ClimbingArea] {
        var components = URLComponents(
            url: baseURL.appending(path: "api/v1/areas"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "bbox", value: bounds.queryValue)
        ]

        guard let url = components?.url else {
            throw APIClientError.invalidURL
        }

        let response: ListResponse<ClimbingArea> = try await get(url)
        return response.data
    }

    func routes(
        for areaID: String,
        filters: RouteFilters = RouteFilters()
    ) async throws -> [ClimbingRoute] {
        var components = URLComponents(
            url: baseURL.appending(path: "api/v1/areas/\(areaID)/routes"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = filters.queryItems.isEmpty ? nil : filters.queryItems

        guard let url = components?.url else {
            throw APIClientError.invalidURL
        }

        let response: ListResponse<ClimbingRoute> = try await get(url)
        return response.data
    }

    func route(id: String) async throws -> ClimbingRoute {
        let url = baseURL.appending(path: "api/v1/routes/\(id)")
        let response: ItemResponse<ClimbingRoute> = try await get(url)
        return response.data
    }

    func search(_ query: String) async throws -> SearchResults {
        var components = URLComponents(
            url: baseURL.appending(path: "api/v1/search"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]

        guard let url = components?.url else {
            throw APIClientError.invalidURL
        }

        let response: SearchResponse = try await get(url)
        return response.data
    }

    func personalRoutes() async throws -> [PersonalRoute] {
        let url = baseURL.appending(path: "api/v1/me/routes")
        let response: ListResponse<PersonalRoute> = try await authenticatedRequest(
            url: url,
            method: "GET"
        )
        return response.data
    }

    func personalRouteState(routeID: String) async throws -> PersonalRouteState {
        let url = baseURL.appending(path: "api/v1/me/routes/\(routeID)")
        let response: ItemResponse<PersonalRouteState> = try await authenticatedRequest(
            url: url,
            method: "GET"
        )
        return response.data
    }

    func updatePersonalRouteState(
        routeID: String,
        isSaved: Bool,
        isTicked: Bool
    ) async throws -> PersonalRouteState {
        let url = baseURL.appending(path: "api/v1/me/routes/\(routeID)")
        let response: ItemResponse<PersonalRouteState> = try await authenticatedRequest(
            url: url,
            method: "PUT",
            body: PersonalRouteUpdate(isSaved: isSaved, isTicked: isTicked)
        )
        return response.data
    }

    private func get<Response: Decodable & Sendable>(_ url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }

        return try decoder.decode(Response.self, from: data)
    }

    private func authenticatedRequest<Response: Decodable & Sendable>(
        url: URL,
        method: String
    ) async throws -> Response {
        try await authenticatedRequest(
            url: url,
            method: method,
            encodedBody: nil
        )
    }

    private func authenticatedRequest<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        url: URL,
        method: String,
        body: Body
    ) async throws -> Response {
        try await authenticatedRequest(
            url: url,
            method: method,
            encodedBody: try JSONEncoder().encode(body)
        )
    }

    private func authenticatedRequest<Response: Decodable & Sendable>(
        url: URL,
        method: String,
        encodedBody: Data?
    ) async throws -> Response {
        guard let idToken = try await authTokenProvider() else {
            throw APIClientError.authenticationRequired
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        if let encodedBody {
            request.httpBody = encodedBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }

        return try decoder.decode(Response.self, from: data)
    }
}
