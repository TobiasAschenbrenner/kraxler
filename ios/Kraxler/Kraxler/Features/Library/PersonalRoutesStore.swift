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
    private var isLoading = false

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load(force: Bool = false) async {
        if isLoading || (!force && loadState == .loaded) {
            return
        }

        let hasExistingContent = loadState == .loaded || !routes.isEmpty
        isLoading = true
        if !hasExistingContent {
            loadState = .loading
        }

        defer {
            isLoading = false
        }

        do {
            let personalRoutes = try await apiClient.personalRoutes()
            try Task.checkCancellation()
            routes = personalRoutes
            statesByRouteID = Dictionary(
                uniqueKeysWithValues: personalRoutes.map { ($0.routeId, $0.state) }
            )
            loadState = .loaded
        } catch is CancellationError {
            loadState = hasExistingContent ? .loaded : .idle
        } catch {
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

        let state = try await apiClient.personalRouteState(routeID: routeID)
        statesByRouteID[routeID] = state
        return state
    }

    func update(
        route: ClimbingRoute,
        areaName: String? = nil,
        isSaved: Bool,
        isTicked: Bool
    ) async throws -> PersonalRouteState {
        let previousState = statesByRouteID[route.id] ?? .empty(routeID: route.id)
        let optimisticState = PersonalRouteState(
            routeId: route.id,
            isSaved: isSaved,
            isTicked: isTicked,
            tickedAt: isTicked ? previousState.tickedAt : nil
        )
        apply(optimisticState, to: route, areaName: areaName)

        do {
            let confirmedState = try await apiClient.updatePersonalRouteState(
                routeID: route.id,
                isSaved: isSaved,
                isTicked: isTicked
            )
            apply(confirmedState, to: route, areaName: areaName)
            loadState = .loaded
            return confirmedState
        } catch {
            apply(previousState, to: route, areaName: areaName)
            throw error
        }
    }

    func reset() {
        routes = []
        statesByRouteID = [:]
        loadState = .idle
    }

    private func apply(
        _ state: PersonalRouteState,
        to route: ClimbingRoute,
        areaName: String?
    ) {
        statesByRouteID[route.id] = state

        guard state.isSaved || state.isTicked else {
            routes.removeAll { $0.routeId == route.id }
            return
        }

        let knownAreaName = areaName
            ?? routes.first(where: { $0.routeId == route.id })?.areaName
        let personalRoute = PersonalRoute(
            route: route,
            areaName: knownAreaName,
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
