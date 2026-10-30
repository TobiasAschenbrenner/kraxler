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

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load(force: Bool = false) async {
        if !force, loadState == .loaded {
            return
        }

        loadState = .loading

        do {
            let personalRoutes = try await apiClient.personalRoutes()
            guard !Task.isCancelled else {
                return
            }
            routes = personalRoutes
            statesByRouteID = Dictionary(
                uniqueKeysWithValues: personalRoutes.map { ($0.routeId, $0.state) }
            )
            loadState = .loaded
        } catch is CancellationError {
            return
        } catch {
            loadState = .failed("Your routes could not be loaded.")
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
        apply(optimisticState, to: route)

        do {
            let confirmedState = try await apiClient.updatePersonalRouteState(
                routeID: route.id,
                isSaved: isSaved,
                isTicked: isTicked
            )
            apply(confirmedState, to: route)
            loadState = .loaded
            return confirmedState
        } catch {
            apply(previousState, to: route)
            throw error
        }
    }

    func reset() {
        routes = []
        statesByRouteID = [:]
        loadState = .idle
    }

    private func apply(_ state: PersonalRouteState, to route: ClimbingRoute) {
        statesByRouteID[route.id] = state

        guard state.isSaved || state.isTicked else {
            routes.removeAll { $0.routeId == route.id }
            return
        }

        let personalRoute = PersonalRoute(
            route: route,
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
