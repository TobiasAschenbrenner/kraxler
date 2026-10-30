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
    case httpStatus(Int)
}

nonisolated struct APIClient: Sendable {
    private struct ListResponse<Value: Decodable & Sendable>: Decodable, Sendable {
        let data: [Value]
    }

    private struct ItemResponse<Value: Decodable & Sendable>: Decodable, Sendable {
        let data: Value
    }

    private struct SearchResponse: Decodable, Sendable {
        let data: SearchResults
    }

    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "http://localhost:3000")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
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

    func routes(for areaID: String) async throws -> [ClimbingRoute] {
        let url = baseURL.appending(path: "api/v1/areas/\(areaID)/routes")
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
}
