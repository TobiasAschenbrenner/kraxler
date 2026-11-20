import SwiftUI

struct RouteDetailScreen: View {
    private enum RouteState {
        case loading
        case loaded(ClimbingRoute, ClimbingContentSource)
        case failed(String)
        case notAvailableOffline
    }

    private let routeID: String
    private let climbingRepository: ClimbingRepository
    private let loadsRemoteRoute: Bool
    private let personalRoutesStore: PersonalRoutesStore?
    private let areaName: String?
    private let climbingAreaID: String?

    @Environment(AuthSession.self) private var authSession
    @State private var routeState: RouteState
    @State private var personalRouteState: PersonalRouteState
    @State private var isUpdatingPersonalRoute = false
    @State private var personalRouteErrorMessage: String?

    init(
        routeID: String,
        apiClient: APIClient = APIClient(),
        climbingRepository: ClimbingRepository? = nil,
        initialRoute: ClimbingRoute? = nil,
        areaName: String? = nil,
        climbingAreaID: String? = nil,
        loadsRemoteRoute: Bool = true,
        personalRoutesStore: PersonalRoutesStore? = nil
    ) {
        self.routeID = routeID
        self.climbingRepository = climbingRepository ?? ClimbingRepository(apiClient: apiClient)
        self.loadsRemoteRoute = loadsRemoteRoute
        self.personalRoutesStore = personalRoutesStore
        self.areaName = areaName
        self.climbingAreaID = climbingAreaID
        _routeState = State(
            initialValue: initialRoute.map { RouteState.loaded($0, .remote) } ?? .loading
        )
        _personalRouteState = State(
            initialValue: .empty(routeID: routeID)
        )
    }

    var body: some View {
        content
            .toolbarBackground(.hidden, for: .navigationBar)
            .task(
                id: RouteContentRequestKey(
                    routeID: routeID, connectionRevision: climbingRepository.connectionRevision)
            ) {
                guard loadsRemoteRoute else {
                    return
                }

                await loadRoute()
            }
            .task(
                id: PersonalRouteRequestKey(
                    routeID: routeID,
                    accountID: authSession.account?.id
                )
            ) {
                await loadPersonalRouteState()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch routeState {
        case .loading:
            ProgressView("Loading route…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let route, let source):
            RouteDetailContent(
                route: route, source: source,
                localTopoURLs: climbingRepository.localTopoURLs(for: route)
            ) {
                personalRouteActions(for: route)
            }

        case .notAvailableOffline:
            ContentUnavailableView("Not available offline", systemImage: "wifi.slash")

        case .failed(let message):
            ContentUnavailableView {
                Label("Route unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    Task {
                        await loadRoute()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private func personalRouteActions(for route: ClimbingRoute) -> some View {
        if personalRoutesStore != nil {
            PersonalRouteActions(
                state: personalRouteState,
                isUpdating: isUpdatingPersonalRoute,
                errorMessage: personalRouteErrorMessage,
                onSave: {
                    await updatePersonalRoute(
                        route: route, isSaved: !personalRouteState.isSaved,
                        isTicked: personalRouteState.isTicked)
                },
                onTick: {
                    await updatePersonalRoute(
                        route: route, isSaved: personalRouteState.isSaved,
                        isTicked: !personalRouteState.isTicked)
                }
            )
        }
    }

    private func loadRoute() async {
        let previousState = routeState
        if case .loaded = routeState {} else { routeState = .loading }

        do {
            let response = try await climbingRepository.route(id: routeID)
            guard !Task.isCancelled else {
                return
            }
            routeState = .loaded(response.value, response.source)
        } catch is CancellationError {
            return
        } catch ClimbingRepositoryError.notAvailableOffline {
            guard !Task.isCancelled else { return }
            if case .loaded = previousState {
                routeState = previousState
            } else {
                routeState = .notAvailableOffline
            }
        } catch {
            guard !Task.isCancelled else { return }
            if case .loaded = previousState {
                routeState = previousState
            } else {
                routeState = .failed("The route details could not be loaded.")
            }
        }
    }

    private func loadPersonalRouteState() async {
        guard
            let personalRoutesStore,
            authSession.isAuthenticated
        else {
            personalRouteState = .empty(routeID: routeID)
            personalRouteErrorMessage = nil
            return
        }

        personalRoutesStore.selectAccount(authSession.account?.id)
        do {
            personalRouteState = try await personalRoutesStore.state(
                for: routeID,
                force: true
            )
        } catch is CancellationError {
            return
        } catch {
            personalRouteErrorMessage = "Your route status could not be loaded."
        }
    }

    private func updatePersonalRoute(
        route: ClimbingRoute,
        isSaved: Bool,
        isTicked: Bool
    ) async {
        guard let personalRoutesStore else {
            return
        }

        let previousState = personalRouteState
        personalRouteState = PersonalRouteState(
            routeId: route.id,
            isSaved: isSaved,
            isTicked: isTicked,
            tickedAt: isTicked ? previousState.tickedAt : nil
        )
        isUpdatingPersonalRoute = true
        personalRouteErrorMessage = nil

        defer {
            isUpdatingPersonalRoute = false
        }

        do {
            personalRouteState = try await personalRoutesStore.update(
                route: route,
                areaName: areaName,
                climbingAreaID: climbingAreaID,
                isSaved: isSaved,
                isTicked: isTicked
            )
        } catch {
            personalRouteState = previousState
            personalRouteErrorMessage = "Your library could not be updated."
        }
    }
}

private struct PersonalRouteRequestKey: Hashable {
    let routeID: String
    let accountID: String?
}

private struct RouteContentRequestKey: Hashable {
    let routeID: String
    let connectionRevision: Int
}
