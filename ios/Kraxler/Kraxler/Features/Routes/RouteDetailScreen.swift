import MapboxMaps
import SwiftUI

struct RouteDetailScreen: View {
    private enum RouteState {
        case loading
        case loaded(ClimbingRoute, ClimbingContentSource)
        case failed(String)
    }

    private let routeID: String
    private let climbingRepository: ClimbingRepository
    private let loadsRemoteRoute: Bool
    private let personalRoutesStore: PersonalRoutesStore?

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
        loadsRemoteRoute: Bool = true,
        personalRoutesStore: PersonalRoutesStore? = nil
    ) {
        self.routeID = routeID
        self.climbingRepository = climbingRepository ?? ClimbingRepository(apiClient: apiClient)
        self.loadsRemoteRoute = loadsRemoteRoute
        self.personalRoutesStore = personalRoutesStore
        _routeState = State(
            initialValue: initialRoute.map { RouteState.loaded($0, .remote) } ?? .loading
        )
        _personalRouteState = State(
            initialValue: .empty(routeID: routeID)
        )
    }

    var body: some View {
        content
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: routeID) {
                guard loadsRemoteRoute else {
                    return
                }

                await loadRoute()
            }
            .task(id: PersonalRouteRequestKey(
                routeID: routeID,
                accountID: authSession.account?.id
            )) {
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
            RouteDetailContent(route: route, source: source) {
                personalRouteActions(for: route)
            }

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
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    personalRouteButton(
                        title: personalRouteState.isSaved ? "Saved" : "Save",
                        systemImage: personalRouteState.isSaved
                            ? "bookmark.fill"
                            : "bookmark",
                        isActive: personalRouteState.isSaved,
                        color: KraxlerDesign.accent
                    ) {
                        await updatePersonalRoute(
                            route: route,
                            isSaved: !personalRouteState.isSaved,
                            isTicked: personalRouteState.isTicked
                        )
                    }
                    .accessibilityIdentifier("route-save-button")

                    personalRouteButton(
                        title: personalRouteState.isTicked ? "Ticked" : "Tick",
                        systemImage: personalRouteState.isTicked
                            ? "checkmark.circle.fill"
                            : "checkmark.circle",
                        isActive: personalRouteState.isTicked,
                        color: KraxlerDesign.success
                    ) {
                        await updatePersonalRoute(
                            route: route,
                            isSaved: personalRouteState.isSaved,
                            isTicked: !personalRouteState.isTicked
                        )
                    }
                    .accessibilityIdentifier("route-tick-button")
                }

                if isUpdatingPersonalRoute {
                    ProgressView("Updating your library…")
                        .font(.caption)
                }

                if let personalRouteErrorMessage {
                    Text(personalRouteErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("personal-route-error")
                }
            }
        }
    }

    private func personalRouteButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        color: Color,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(isActive ? .white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isActive ? color.gradient : Color(.secondarySystemGroupedBackground).gradient,
                    in: RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
                )
                .overlay {
                    if !isActive {
                        RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
                            .stroke(color.opacity(0.28))
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(isUpdatingPersonalRoute)
    }

    private var navigationTitle: String {
        switch routeState {
        case .loaded(let route, _):
            route.name
        case .loading, .failed:
            "Route details"
        }
    }

    private func loadRoute() async {
        routeState = .loading

        do {
            let response = try await climbingRepository.route(id: routeID)
            guard !Task.isCancelled else {
                return
            }
            routeState = .loaded(response.value, response.source)
        } catch is CancellationError {
            return
        } catch {
            routeState = .failed("The route details could not be loaded.")
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

        isUpdatingPersonalRoute = true
        personalRouteErrorMessage = nil

        defer {
            isUpdatingPersonalRoute = false
        }

        do {
            personalRouteState = try await personalRoutesStore.update(
                route: route,
                isSaved: isSaved,
                isTicked: isTicked
            )
        } catch {
            personalRouteErrorMessage = "Your library could not be updated."
        }
    }
}

private struct PersonalRouteRequestKey: Hashable {
    let routeID: String
    let accountID: String?
}

private struct RouteDetailContent<Actions: View>: View {
    let route: ClimbingRoute
    let source: ClimbingContentSource
    let actions: Actions

    init(
        route: ClimbingRoute,
        source: ClimbingContentSource,
        @ViewBuilder actions: () -> Actions
    ) {
        self.route = route
        self.source = source
        self.actions = actions()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                actions
                facts
                styles

                if let description = route.description, !description.isEmpty {
                    section("Description") {
                        Text(description)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .kraxlerCard()
                            .accessibilityIdentifier("route-detail-description")
                    }
                }

                location
            }
            .padding()
        }
        .background(KraxlerScreenBackground())
        .accessibilityIdentifier("route-detail-screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(route.grade.value)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(KraxlerDesign.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("route-detail-grade")

                Spacer()

                if source == .offline {
                    Label("Offline", systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.18), in: Capsule())
                        .accessibilityIdentifier("offline-route-indicator")
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(route.name)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("route-detail-name")

                Label(route.discipline.displayName, systemImage: "figure.climbing")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .accessibilityIdentifier("route-detail-discipline")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [KraxlerDesign.accent, Color.orange.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: KraxlerDesign.cardRadius)
        )
        .shadow(color: KraxlerDesign.accent.opacity(0.18), radius: 16, y: 8)
    }

    private var facts: some View {
        section("Climb") {
            HStack(spacing: 10) {
                metricCard(
                    title: "System",
                    value: route.grade.system.displayName,
                    systemImage: "chart.bar.fill"
                )

                if let lengthMeters = route.lengthMeters {
                    metricCard(
                        title: "Length",
                        value: "\(lengthMeters.formatted()) m",
                        systemImage: "ruler.fill"
                    )
                }

                if let pitches = route.pitches {
                    metricCard(
                        title: "Pitches",
                        value: pitches.formatted(),
                        systemImage: "arrow.up.right"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var styles: some View {
        if !route.styles.isEmpty {
            section("Styles") {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(route.styles, id: \.self) { style in
                            Text(style.displayName)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    KraxlerDesign.accent.opacity(0.12),
                                    in: Capsule()
                                )
                        }
                    }
                }
                .scrollIndicators(.hidden)
                    .accessibilityIdentifier("route-detail-styles")
            }
        }
    }

    private var location: some View {
        section("Location") {
            VStack(alignment: .leading, spacing: 12) {
                MapboxMaps.Map(
                    initialViewport: .camera(
                        center: route.location.coordinate,
                        zoom: 16
                    )
                ) {
                    MapViewAnnotation(coordinate: route.location.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(.orange)
                            .background(.white, in: Circle())
                            .accessibilityHidden(true)
                    }
                    .allowHitTesting(false)
                }
                .mapStyle(.standard)
                .allowsHitTesting(false)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: KraxlerDesign.cardRadius))

                Text(coordinateText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("route-detail-location")
            }
        }
    }

    private var coordinateText: String {
        let coordinate = route.location.coordinate
        let latitude = coordinate.latitude.formatted(
            .number.precision(.fractionLength(5))
        )
        let longitude = coordinate.longitude.formatted(
            .number.precision(.fractionLength(5))
        )
        return "\(latitude), \(longitude)"
    }

    private func metricCard(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: systemImage)
                .foregroundStyle(KraxlerDesign.accent)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kraxlerCard()
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

#if DEBUG
extension ClimbingRoute {
    static let routeDetailFixture = ClimbingRoute(
        id: "route-detail-fixture",
        areaId: "bas-cuvier",
        name: "La Marie Rose",
        location: GeoJSONPoint(
            type: "Point",
            coordinates: [2.63823, 48.44704]
        ),
        discipline: .bouldering,
        grade: Grade(system: .fontainebleau, value: "6A", rank: 22),
        styles: [.overhang],
        lengthMeters: 5,
        pitches: 1,
        description: "A historic, slightly overhanging problem with polished holds."
    )
}

#Preview("Route details") {
    NavigationStack {
        RouteDetailScreen(
            routeID: ClimbingRoute.routeDetailFixture.id,
            initialRoute: .routeDetailFixture,
            loadsRemoteRoute: false
        )
    }
    .environment(AuthSession())
}

#Preview("Loading error") {
    NavigationStack {
        RouteDetailScreen(
            routeID: "missing-route",
            apiClient: APIClient(baseURL: URL(string: "http://localhost:1")!)
        )
    }
    .environment(AuthSession())
}
#endif
