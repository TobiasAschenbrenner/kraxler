import Foundation

nonisolated enum ClimbingContentSource: Equatable, Sendable {
    case remote
    case offline
}

nonisolated struct ClimbingContentResponse<Value: Sendable>: Sendable {
    let value: Value
    let source: ClimbingContentSource
}

enum ClimbingRepositoryError: Error {
    case offlineStoreUnavailable
    case downloadedContentUnavailable
}

@MainActor
final class ClimbingRepository {
    private let apiClient: APIClient
    private let offlineStore: OfflineClimbingStore?

    init(
        apiClient: APIClient,
        offlineStore: OfflineClimbingStore? = nil
    ) {
        self.apiClient = apiClient
        self.offlineStore = offlineStore
    }

    func areas(in bounds: MapBounds) async throws -> ClimbingContentResponse<[ClimbingArea]> {
        do {
            return ClimbingContentResponse(
                value: try await apiClient.areas(in: bounds),
                source: .remote
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard let offlineStore else {
                throw error
            }

            let downloadedAreas = try offlineStore.areas(in: bounds)
            guard !downloadedAreas.isEmpty else {
                throw error
            }

            return ClimbingContentResponse(
                value: downloadedAreas,
                source: .offline
            )
        }
    }

    func routes(
        for areaID: String,
        filters: RouteFilters = RouteFilters()
    ) async throws -> ClimbingContentResponse<[ClimbingRoute]> {
        do {
            return ClimbingContentResponse(
                value: try await apiClient.routes(for: areaID, filters: filters),
                source: .remote
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard
                let offlineStore,
                try offlineStore.manifest(for: areaID) != nil
            else {
                throw error
            }

            let downloadedRoutes = try offlineStore.routes(for: areaID)
                .filter { $0.matches(filters) }

            return ClimbingContentResponse(
                value: downloadedRoutes,
                source: .offline
            )
        }
    }

    func route(id routeID: String) async throws -> ClimbingContentResponse<ClimbingRoute> {
        do {
            return ClimbingContentResponse(
                value: try await apiClient.route(id: routeID),
                source: .remote
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard
                let offlineStore,
                let downloadedRoute = try offlineStore.route(id: routeID)
            else {
                throw error
            }

            return ClimbingContentResponse(
                value: downloadedRoute,
                source: .offline
            )
        }
    }

    func search(_ query: String) async throws -> ClimbingContentResponse<SearchResults> {
        do {
            return ClimbingContentResponse(
                value: try await apiClient.search(query),
                source: .remote
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard
                let offlineStore,
                try !offlineStore.manifests().isEmpty
            else {
                throw error
            }

            return ClimbingContentResponse(
                value: try offlineStore.search(query),
                source: .offline
            )
        }
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
