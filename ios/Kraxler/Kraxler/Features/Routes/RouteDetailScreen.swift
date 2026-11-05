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
    private let areaName: String?

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
        loadsRemoteRoute: Bool = true,
        personalRoutesStore: PersonalRoutesStore? = nil
    ) {
        self.routeID = routeID
        self.climbingRepository = climbingRepository ?? ClimbingRepository(apiClient: apiClient)
        self.loadsRemoteRoute = loadsRemoteRoute
        self.personalRoutesStore = personalRoutesStore
        self.areaName = areaName
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
            HStack(spacing: 10) {
                HStack(spacing: 10) {
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
                        color: KraxlerDesign.accent
                    ) {
                        await updatePersonalRoute(
                            route: route,
                            isSaved: personalRouteState.isSaved,
                            isTicked: !personalRouteState.isTicked
                        )
                    }
                    .accessibilityIdentifier("route-tick-button")
                }

                if let personalRouteErrorMessage {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(KraxlerDesign.warning)
                        .accessibilityLabel(personalRouteErrorMessage)
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
            Image(systemName: systemImage)
        }
        .buttonStyle(
            KraxlerIconButtonStyle(
                foregroundStyle: isActive ? color : .secondary
            )
        )
        .accessibilityLabel(title)
        .accessibilityValue(isActive ? "Selected" : "Not selected")
        .disabled(isUpdatingPersonalRoute)
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

private struct RouteDetailContent<Actions: View>: View {
    let route: ClimbingRoute
    let source: ClimbingContentSource
    let actions: Actions

    @Environment(\.colorScheme) private var colorScheme

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
            VStack(alignment: .leading, spacing: 22) {
                mapHero
                routeHeader
                facts

                if !route.styles.isEmpty {
                    styles
                }

                if let description = route.description, !description.isEmpty {
                    section("Description") {
                        Text(description)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("route-detail-description")
                    }
                }

                coordinate
            }
            .padding(.horizontal, KraxlerDesign.pagePadding)
            .padding(.bottom, 32)
        }
        .background(KraxlerScreenBackground())
        .ignoresSafeArea(edges: .top)
        .accessibilityIdentifier("route-detail-screen")
    }

    private var mapHero: some View {
        MapboxMaps.Map(
            initialViewport: .camera(
                center: route.location.coordinate,
                zoom: 16
            )
        ) {
            MapViewAnnotation(coordinate: route.location.coordinate) {
                Circle()
                    .fill(KraxlerDesign.accent)
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle().stroke(.white, lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .accessibilityHidden(true)
            }
            .allowHitTesting(false)
        }
        .mapStyle(mapStyle)
        .gestureOptions(staticMapGestureOptions)
        .ornamentOptions(staticMapOrnamentOptions)
        .frame(height: 280)
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerRelativeFrame(.horizontal)
        .padding(.horizontal, -KraxlerDesign.pagePadding)
        .overlay(alignment: .bottomTrailing) {
            if source == .offline {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(KraxlerDesign.accent)
                    .padding(12)
                    .kraxlerGlassSurface(cornerRadius: 24)
                    .padding(16)
                    .accessibilityLabel("Available offline")
                    .accessibilityIdentifier("offline-route-indicator")
            }
        }
    }

    private var mapStyle: MapStyle {
        .standard(
            theme: .monochrome,
            lightPreset: colorScheme == .dark ? .night : .day,
            showPointOfInterestLabels: false,
            showTransitLabels: false,
            showPlaceLabels: false,
            showRoadLabels: true,
            show3dObjects: false
        )
    }

    private var staticMapGestureOptions: GestureOptions {
        GestureOptions(
            panEnabled: false,
            pinchEnabled: false,
            rotateEnabled: false,
            simultaneousRotateAndPinchZoomEnabled: false,
            pinchZoomEnabled: false,
            pinchPanEnabled: false,
            pitchEnabled: false,
            doubleTapToZoomInEnabled: false,
            doubleTouchToZoomOutEnabled: false,
            quickZoomEnabled: false
        )
    }

    private var staticMapOrnamentOptions: OrnamentOptions {
        OrnamentOptions(
            scaleBar: ScaleBarViewOptions(visibility: .hidden),
            compass: CompassViewOptions(visibility: .hidden),
            logo: LogoViewOptions(
                position: .bottomLeading,
                margins: CGPoint(x: 12, y: 10)
            ),
            attributionButton: AttributionButtonOptions(
                position: .bottomTrailing,
                margins: CGPoint(x: 12, y: 10),
                tintColor: .label
            )
        )
    }

    private var routeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(route.name)
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier("route-detail-name")

                    HStack(spacing: 8) {
                        Text(route.grade.value)
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(KraxlerDesign.accent)
                            .accessibilityIdentifier("route-detail-grade")

                        Text(route.discipline.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("route-detail-discipline")
                    }
                }

                Spacer(minLength: 8)
                actions
            }

            if !route.styles.isEmpty {
                Text(route.styles.map(\.displayName).joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var facts: some View {
        HStack(spacing: 0) {
            fact(
                title: "Grade system",
                value: route.grade.system.displayName,
                systemImage: "chart.bar"
            )

            if let lengthMeters = route.lengthMeters {
                Divider().frame(height: 38)
                fact(
                    title: "Length",
                    value: "\(lengthMeters.formatted()) m",
                    systemImage: "ruler"
                )
            }

            if let pitches = route.pitches {
                Divider().frame(height: 38)
                fact(
                    title: "Pitches",
                    value: pitches.formatted(),
                    systemImage: "arrow.up.right"
                )
            }
        }
        .padding(.vertical, 14)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
        )
    }

    private var styles: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(route.styles, id: \.self) { style in
                    Text(style.displayName)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Color(.secondarySystemBackground),
                            in: Capsule()
                        )
                    }
                }
            }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("route-detail-styles")
    }

    private var coordinate: some View {
        Label(coordinateText, systemImage: "location")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("route-detail-location")
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

    private func fact(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        VStack(spacing: 5) {
            Label(value, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KraxlerDesign.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
