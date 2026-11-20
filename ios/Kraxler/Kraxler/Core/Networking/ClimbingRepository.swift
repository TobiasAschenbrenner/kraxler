import Foundation

nonisolated enum ClimbingContentSource: Equatable, Sendable {
    case remote
    case offline
}

nonisolated struct ClimbingContentResponse<Value: Sendable>: Sendable {
    let value: Value
    let source: ClimbingContentSource
}

enum ClimbingRepositoryError: Error, Equatable {
    case offlineStoreUnavailable
    case downloadedContentUnavailable
    case notAvailableOffline
}

@MainActor
final class ClimbingRepository {
    private let apiClient: APIClient
    private let offlineStore: OfflineClimbingStore?
    private let connectivity: ConnectivityMonitor?

    var isOffline: Bool { connectivity?.isOffline ?? false }
    var connectionRevision: Int { connectivity?.revision ?? 0 }
    var showsOfflineIndicator: Bool { connectivity?.showsOfflineIndicator ?? false }

    init(
        apiClient: APIClient,
        offlineStore: OfflineClimbingStore? = nil,
        connectivity: ConnectivityMonitor? = nil
    ) {
        self.apiClient = apiClient
        self.offlineStore = offlineStore
        self.connectivity = connectivity
    }

    func areas(in bounds: MapBounds) async throws -> ClimbingContentResponse<[ClimbingArea]> {
        try Task.checkCancellation()
        if isOffline { return try downloadedAreas(in: bounds) }
        do {
            return ClimbingContentResponse(value: try await apiClient.areas(in: bounds), source: .remote)
        } catch {
            try Self.checkCancellation(error)
            let cached = try downloadedAreas(in: bounds)
            guard !cached.value.isEmpty || isOffline || Self.isConnectionLoss(error) else { throw error }
            return cached
        }
    }

    func routes(
        for areaID: String,
        filters: RouteFilters = RouteFilters()
    ) async throws -> ClimbingContentResponse<[ClimbingRoute]> {
        try Task.checkCancellation()
        if isOffline { return try downloadedRoutes(for: areaID, filters: filters) }
        do {
            return ClimbingContentResponse(
                value: try await apiClient.routes(for: areaID, filters: filters), source: .remote
            )
        } catch {
            try Self.checkCancellation(error)
            if let offlineStore, try offlineStore.manifest(for: areaID) != nil {
                return try downloadedRoutes(for: areaID, filters: filters)
            }
            if isOffline || Self.isConnectionLoss(error) { throw ClimbingRepositoryError.notAvailableOffline }
            throw error
        }
    }

    func route(id routeID: String) async throws -> ClimbingContentResponse<ClimbingRoute> {
        try Task.checkCancellation()
        if isOffline { return try downloadedRoute(id: routeID) }
        do {
            return ClimbingContentResponse(value: try await apiClient.route(id: routeID), source: .remote)
        } catch {
            try Self.checkCancellation(error)
            if let route = try offlineStore?.route(id: routeID) {
                return ClimbingContentResponse(value: route, source: .offline)
            }
            if isOffline || Self.isConnectionLoss(error) { throw ClimbingRepositoryError.notAvailableOffline }
            throw error
        }
    }

    func search(_ query: String) async throws -> ClimbingContentResponse<SearchResults> {
        try Task.checkCancellation()
        if isOffline { return try downloadedSearch(query) }
        do {
            return ClimbingContentResponse(value: try await apiClient.search(query), source: .remote)
        } catch {
            try Self.checkCancellation(error)
            let hasDownloads = try !offlineManifests().isEmpty
            if isOffline || Self.isConnectionLoss(error) || hasDownloads {
                return try downloadedSearch(query)
            }
            throw error
        }
    }

    private func downloadedAreas(in bounds: MapBounds) throws -> ClimbingContentResponse<[ClimbingArea]> {
        ClimbingContentResponse(value: try offlineStore?.areas(in: bounds) ?? [], source: .offline)
    }

    private func downloadedRoutes(
        for areaID: String, filters: RouteFilters
    ) throws -> ClimbingContentResponse<[ClimbingRoute]> {
        guard let offlineStore, try offlineStore.manifest(for: areaID) != nil else {
            throw ClimbingRepositoryError.notAvailableOffline
        }
        return ClimbingContentResponse(
            value: try offlineStore.routes(for: areaID).filter { $0.matches(filters) }, source: .offline
        )
    }

    private func downloadedRoute(id routeID: String) throws -> ClimbingContentResponse<ClimbingRoute> {
        guard let route = try offlineStore?.route(id: routeID) else {
            throw ClimbingRepositoryError.notAvailableOffline
        }
        return ClimbingContentResponse(value: route, source: .offline)
    }

    private func downloadedSearch(_ query: String) throws -> ClimbingContentResponse<SearchResults> {
        ClimbingContentResponse(
            value: try offlineStore?.search(query) ?? SearchResults(areas: [], routes: []), source: .offline
        )
    }

    private static func checkCancellation(_ error: Error) throws {
        if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
            throw CancellationError()
        }
    }

    private static func isConnectionLoss(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        return [.notConnectedToInternet, .networkConnectionLost].contains(error.code)
    }

    @discardableResult
    func download(_ area: ClimbingArea) async throws -> OfflineAreaManifest {
        guard let offlineStore else {
            throw ClimbingRepositoryError.offlineStoreUnavailable
        }

        let routes = try await apiClient.routes(for: area.id)
        try offlineStore.save(area: area, routes: routes)

        guard let manifest = try offlineStore.manifest(for: area.id) else {
            throw ClimbingRepositoryError.downloadedContentUnavailable
        }
        return manifest
    }

    func removeDownload(for areaID: String) throws {
        guard let offlineStore else {
            throw ClimbingRepositoryError.offlineStoreUnavailable
        }
        try offlineStore.remove(areaID: areaID)
    }

    func offlineManifests() throws -> [OfflineAreaManifest] {
        guard let offlineStore else {
            return []
        }
        return try offlineStore.manifests()
    }
}

private extension ClimbingRoute {
    func matches(_ filters: RouteFilters) -> Bool {
        if let discipline = filters.discipline, self.discipline != discipline {
            return false
        }

        if let gradeSystem = filters.gradeSystem, grade.system != gradeSystem {
            return false
        }

        if let gradeMin = filters.gradeMin,
           let rank = grade.system.rank(for: gradeMin),
           grade.rank < rank {
            return false
        }

        if let gradeMax = filters.gradeMax,
           let rank = grade.system.rank(for: gradeMax),
           grade.rank > rank {
            return false
        }

        if !filters.styles.isEmpty,
           filters.styles.isDisjoint(with: Set(styles)) {
            return false
        }

        if let lengthMin = filters.lengthMin,
           (lengthMeters ?? 0) < Double(lengthMin) {
            return false
        }

        if let lengthMax = filters.lengthMax,
           (lengthMeters ?? .greatestFiniteMagnitude) > Double(lengthMax) {
            return false
        }

        if let pitchesMin = filters.pitchesMin,
           (pitches ?? 0) < pitchesMin {
            return false
        }

        if let pitchesMax = filters.pitchesMax,
           (pitches ?? .max) > pitchesMax {
            return false
        }

        return true
    }
}

private extension ClimbingRoute.GradeSystem {
    func rank(for value: String) -> Int? {
        values.firstIndex(of: value).map { $0 + 1 }
    }
}
