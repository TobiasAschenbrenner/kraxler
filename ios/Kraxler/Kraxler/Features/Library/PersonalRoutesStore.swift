import Foundation
import Observation

@MainActor
@Observable
final class PersonalRoutesStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var routes: [PersonalRoute] = []
    private(set) var loadState: LoadState = .idle

    private let apiClient: APIClient
    private var statesByRouteID: [String: PersonalRouteState] = [:]
    private var loadingRequestID: UUID?
    private var sessionID = UUID()
    private var accountID: String?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load(force: Bool = false) async {
        if loadingRequestID != nil || (!force && loadState == .loaded) {
            return
        }

        let hasExistingContent = loadState == .loaded || !routes.isEmpty
        let requestID = UUID()
        let currentSession = sessionID
        loadingRequestID = requestID
        if !hasExistingContent {
            loadState = .loading
        }

        defer {
            if loadingRequestID == requestID { loadingRequestID = nil }
        }

        do {
            let personalRoutes = try await apiClient.personalRoutes()
            try Task.checkCancellation()
            guard sessionID == currentSession else { return }
            routes = personalRoutes
            statesByRouteID = Dictionary(
                uniqueKeysWithValues: personalRoutes.map { ($0.routeId, $0.state) }
            )
            loadState = .loaded
        } catch is CancellationError {
            guard sessionID == currentSession else { return }
            loadState = hasExistingContent ? .loaded : .idle
        } catch {
            guard sessionID == currentSession else { return }
            if hasExistingContent {
                loadState = .loaded
            } else {
                loadState = .failed("Your routes could not be loaded.")
            }
        }
    }

    func state(for routeID: String, force: Bool = false) async throws -> PersonalRouteState {
        if !force, let cachedState = statesByRouteID[routeID] {
            return cachedState
        }

        let currentSession = sessionID
        let state = try await apiClient.personalRouteState(routeID: routeID)
        try Task.checkCancellation()
        guard sessionID == currentSession else { throw CancellationError() }
        statesByRouteID[routeID] = state
        return state
    }

    func update(
        route: ClimbingRoute,
        areaName: String? = nil,
        climbingAreaID: String? = nil,
        isSaved: Bool,
        isTicked: Bool
    ) async throws -> PersonalRouteState {
        let currentSession = sessionID
        let previousState = statesByRouteID[route.id] ?? .empty(routeID: route.id)
        let previousRoute = routes.first(where: { $0.routeId == route.id })
        let resolvedAreaName = areaName ?? previousRoute?.areaName
        let resolvedClimbingAreaID = climbingAreaID ?? previousRoute?.climbingAreaId
        let optimisticState = PersonalRouteState(
            routeId: route.id,
            isSaved: isSaved,
            isTicked: isTicked,
            tickedAt: isTicked ? previousState.tickedAt : nil
        )
        apply(optimisticState, to: route, areaName: resolvedAreaName, climbingAreaID: resolvedClimbingAreaID)

        do {
            let confirmedState = try await apiClient.updatePersonalRouteState(
                routeID: route.id,
                isSaved: isSaved,
                isTicked: isTicked
            )
            try Task.checkCancellation()
            guard sessionID == currentSession else { throw CancellationError() }
            apply(confirmedState, to: route, areaName: resolvedAreaName, climbingAreaID: resolvedClimbingAreaID)
            loadState = .loaded
            return confirmedState
        } catch {
            guard sessionID == currentSession else { throw CancellationError() }
            apply(previousState, to: route, areaName: resolvedAreaName, climbingAreaID: resolvedClimbingAreaID)
            throw error
        }
    }

    func selectAccount(_ accountID: String?) {
        guard self.accountID != accountID else { return }
        self.accountID = accountID
        reset()
    }

    func reset() {
        sessionID = UUID()
        loadingRequestID = nil
        routes = []
        statesByRouteID = [:]
        loadState = .idle
    }

    private func apply(
        _ state: PersonalRouteState,
        to route: ClimbingRoute,
        areaName: String?,
        climbingAreaID: String?
    ) {
        statesByRouteID[route.id] = state

        guard state.isSaved || state.isTicked else {
            routes.removeAll { $0.routeId == route.id }
            return
        }

        let existingRoute = routes.first(where: { $0.routeId == route.id })
        let knownAreaName = areaName ?? existingRoute?.areaName
        let personalRoute = PersonalRoute(
            route: route,
            areaName: knownAreaName,
            climbingAreaId: climbingAreaID ?? existingRoute?.climbingAreaId,
            routeId: route.id,
            isSaved: state.isSaved,
            isTicked: state.isTicked,
            tickedAt: state.tickedAt
        )

        if let index = routes.firstIndex(where: { $0.routeId == route.id }) {
            routes[index] = personalRoute
        } else {
            routes.insert(personalRoute, at: 0)
        }
    }
}
