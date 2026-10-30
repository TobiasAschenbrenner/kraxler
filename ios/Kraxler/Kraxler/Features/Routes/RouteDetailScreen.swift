import MapKit
import SwiftUI

struct RouteDetailScreen: View {
    private enum RouteState {
        case loading
        case loaded(ClimbingRoute)
        case failed(String)
    }

    private let routeID: String
    private let apiClient: APIClient
    private let loadsRemoteRoute: Bool

    @State private var routeState: RouteState

    init(
        routeID: String,
        apiClient: APIClient = APIClient(),
        initialRoute: ClimbingRoute? = nil,
        loadsRemoteRoute: Bool = true
    ) {
        self.routeID = routeID
        self.apiClient = apiClient
        self.loadsRemoteRoute = loadsRemoteRoute
        _routeState = State(
            initialValue: initialRoute.map(RouteState.loaded) ?? .loading
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
    }

    @ViewBuilder
    private var content: some View {
        switch routeState {
        case .loading:
            ProgressView("Loading route…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let route):
            RouteDetailContent(route: route)

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

    private var navigationTitle: String {
        switch routeState {
        case .loaded(let route):
            route.name
        case .loading, .failed:
            "Route details"
        }
    }

    private func loadRoute() async {
        routeState = .loading

        do {
            let route = try await apiClient.route(id: routeID)
            guard !Task.isCancelled else {
                return
            }
            routeState = .loaded(route)
        } catch is CancellationError {
            return
        } catch {
            routeState = .failed("The route details could not be loaded.")
        }
    }
}

private struct RouteDetailContent: View {
    let route: ClimbingRoute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                facts
                styles

                if let description = route.description, !description.isEmpty {
                    section("Description") {
                        Text(description)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("route-detail-description")
                    }
                }

                location
            }
            .padding()
        }
        .accessibilityIdentifier("route-detail-screen")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(route.grade.value)
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("route-detail-grade")

            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.title2.bold())
                    .accessibilityIdentifier("route-detail-name")

                Text(route.discipline.displayName)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("route-detail-discipline")
            }

            Spacer()
        }
    }

    private var facts: some View {
        section("Climb") {
            VStack(spacing: 0) {
                factRow("Grade system", value: route.grade.system.displayName)

                if let lengthMeters = route.lengthMeters {
                    Divider()
                    factRow("Length", value: "\(lengthMeters.formatted()) m")
                }

                if let pitches = route.pitches {
                    Divider()
                    factRow("Pitches", value: pitches.formatted())
                }
            }
            .padding(.horizontal)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var styles: some View {
        if !route.styles.isEmpty {
            section("Styles") {
                Text(route.styles.map(\.displayName).joined(separator: " · "))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("route-detail-styles")
            }
        }
    }

    private var location: some View {
        section("Location") {
            VStack(alignment: .leading, spacing: 12) {
                Map(
                    initialPosition: .region(
                        MKCoordinateRegion(
                            center: route.location.coordinate,
                            span: MKCoordinateSpan(
                                latitudeDelta: 0.005,
                                longitudeDelta: 0.005
                            )
                        )
                    ),
                    interactionModes: []
                ) {
                    Marker(route.name, coordinate: route.location.coordinate)
                        .tint(.orange)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))

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

    private func factRow(_ label: String, value: String) -> some View {
        LabeledContent(label, value: value)
            .padding(.vertical, 12)
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
}

#Preview("Loading error") {
    NavigationStack {
        RouteDetailScreen(
            routeID: "missing-route",
            apiClient: APIClient(baseURL: URL(string: "http://localhost:1")!)
        )
    }
}
#endif
