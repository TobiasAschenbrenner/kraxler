import CoreLocation
import MapboxMaps
import SwiftUI

struct MapScreen: View {
    private enum SheetDestination: Identifiable {
        case area(ClimbingArea)
        case search

        var id: String {
            switch self {
            case .area(let area):
                "area-\(area.id)"
            case .search:
                "search"
            }
        }
    }

    private static let initialCenter = CLLocationCoordinate2D(
        latitude: 49.1,
        longitude: 6.9
    )
    private static let initialBounds = MapBounds(
        west: 1.65,
        south: 48.05,
        east: 12.15,
        north: 50.15
    )

    private let personalRoutesStore: PersonalRoutesStore?
    private let climbingRepository: ClimbingRepository
    private let offlineDownloadsStore: OfflineDownloadsStore?
    private let loadsRemoteAreas: Bool

    @State private var model: MapScreenModel
    @State private var locationAuthorization = LocationAuthorizationController()
    @State private var viewport: Viewport
    @State private var requestedBounds: MapBounds
    @State private var sheetDestination: SheetDestination?
    @State private var pendingAreaFromSearch: ClimbingArea?

    init(
        apiClient: APIClient = APIClient(),
        personalRoutesStore: PersonalRoutesStore? = nil,
        climbingRepository: ClimbingRepository? = nil,
        offlineDownloadsStore: OfflineDownloadsStore? = nil,
        initialAreas: [ClimbingArea] = [],
        initialErrorMessage: String? = nil,
        loadsRemoteAreas: Bool = true
    ) {
        self.personalRoutesStore = personalRoutesStore
        let repository = climbingRepository ?? ClimbingRepository(apiClient: apiClient)
        self.climbingRepository = repository
        self.offlineDownloadsStore = offlineDownloadsStore
        self.loadsRemoteAreas = loadsRemoteAreas
        _model = State(
            initialValue: MapScreenModel(
                climbingRepository: repository,
                initialAreas: initialAreas,
                initialErrorMessage: initialErrorMessage
            )
        )
        _viewport = State(
            initialValue: .camera(center: Self.initialCenter, zoom: 4.8)
        )
        _requestedBounds = State(initialValue: Self.initialBounds)
    }

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geometry in
                MapReader { proxy in
                    MapboxMaps.Map(viewport: $viewport) {
                        ForEvery(model.visibleAreas) { area in
                            MapViewAnnotation(coordinate: area.location.coordinate) {
                                Button {
                                    sheetDestination = .area(area)
                                } label: {
                                    MapAreaMarker(area: area)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(area.name)
                                .accessibilityIdentifier("map-area-\(area.id)")
                            }
                            .allowOverlap(false)
                            .priority(area.type.annotationPriority)
                        }

                        if locationAuthorization.isAuthorized {
                            Puck2D(bearing: .heading)
                        }
                    }
                    .mapStyle(.standard)
                    .ornamentOptions(
                        OrnamentOptions(
                            scaleBar: ScaleBarViewOptions(visibility: .visible),
                            compass: CompassViewOptions(visibility: .visible)
                        )
                    )
                    .onMapIdle { _ in
                        updateVisibleBounds(
                            using: proxy,
                            mapSize: geometry.size
                        )
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }

            titleCard

            statusOverlay
        }
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            locationControl
        }
        .task(id: requestedBounds) {
            guard loadsRemoteAreas else {
                return
            }
            await model.loadAreas(in: requestedBounds)
        }
        .onChange(of: locationAuthorization.isAuthorized) { _, isAuthorized in
            guard isAuthorized else {
                return
            }

            viewport = .followPuck(zoom: 14, bearing: .heading)
        }
        .sheet(item: $sheetDestination, onDismiss: {
            presentPendingAreaFromSearch()
        }) { destination in
            switch destination {
            case .area(let area):
                AreaDetailSheet(
                    area: area,
                    climbingRepository: climbingRepository,
                    personalRoutesStore: personalRoutesStore,
                    offlineDownloadsStore: offlineDownloadsStore
                )
            case .search:
                MapSearchSheet(
                    climbingRepository: climbingRepository,
                    personalRoutesStore: personalRoutesStore
                ) { area in
                    focusMap(on: area)
                    pendingAreaFromSearch = area
                }
            }
        }
    }

    @ViewBuilder
    private var locationControl: some View {
        if locationAuthorization.isAuthorized {
            Button {
                viewport = .followPuck(zoom: 14, bearing: .heading)
            } label: {
                Image(systemName: "location.fill")
            }
                .accessibilityLabel("Show my location")
                .accessibilityIdentifier("map-user-location-button")
                .locationControlStyle()
        } else {
            Button {
                locationAuthorization.requestAuthorization()
            } label: {
                Image(systemName: locationAuthorization.authorizationStatus == .notDetermined
                    ? "location"
                    : "location.slash")
            }
            .disabled(locationAuthorization.authorizationStatus != .notDetermined)
            .accessibilityLabel(locationAuthorization.authorizationStatus == .notDetermined
                ? "Allow location access"
                : "Location access unavailable")
            .accessibilityIdentifier("map-location-permission-button")
            .locationControlStyle()
        }
    }

    private var titleCard: some View {
        HStack(spacing: 12) {
            KraxlerBrandMark(size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Kraxler")
                    .font(.headline)

                Text(areaCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                sheetDestination = .search
            } label: {
                Label("Search", systemImage: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 13)
                    .frame(height: 40)
                    .background(
                        KraxlerDesign.accent.opacity(0.14),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(KraxlerDesign.accent)
            .accessibilityLabel("Search climbing areas and routes")
            .accessibilityIdentifier("map-search-button")
        }
        .padding(10)
        .kraxlerGlassSurface(cornerRadius: 22)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch model.loadStatus {
        case .idle:
            EmptyView()

        case .loaded:
            if model.contentSource == .offline {
                statusPill {
                    Label("Showing downloaded areas", systemImage: "arrow.down.circle.fill")
                }
            } else if model.visibleAreas.isEmpty {
                statusPill {
                    Label("No climbing areas in this view", systemImage: "map")
                }
            }

        case .loading:
            statusPill {
                ProgressView()
                Text("Loading areas")
            }

        case .failed(let message):
            statusCard {
                VStack(spacing: 10) {
                    Label("Areas unavailable", systemImage: "wifi.exclamationmark")
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)

                    Button("Try again") {
                        Task {
                            await model.loadAreas(in: requestedBounds, force: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func statusCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)
            .padding(.top, 92)
    }

    private func statusPill<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            content()
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 13)
        .frame(minHeight: 38)
        .kraxlerGlassSurface(cornerRadius: 19)
        .padding(.top, 82)
    }

    private var areaCountText: String {
        switch model.loadStatus {
        case .loading where model.visibleAreas.isEmpty:
            "Finding climbing areas…"
        default:
            "\(model.visibleAreas.count) climbing \(model.visibleAreas.count == 1 ? "area" : "areas") in view"
        }
    }

    private func focusMap(on area: ClimbingArea) {
        viewport = .camera(
            center: area.location.coordinate,
            zoom: 13.5
        )
    }

    private func updateVisibleBounds(using proxy: MapProxy, mapSize: CGSize) {
        guard
            mapSize.width > 0,
            mapSize.height > 0,
            let map = proxy.map
        else {
            return
        }

        let bounds = map.coordinateBounds(
            for: CGRect(origin: .zero, size: mapSize)
        )
        requestedBounds = MapBounds(
            southwest: bounds.southwest,
            northeast: bounds.northeast
        )
    }

    private func presentPendingAreaFromSearch() {
        guard let area = pendingAreaFromSearch else {
            return
        }

        pendingAreaFromSearch = nil
        Task { @MainActor in
            await Task.yield()
            sheetDestination = .area(area)
        }
    }
}

private extension View {
    func locationControlStyle() -> some View {
        frame(width: 50, height: 50)
            .foregroundStyle(KraxlerDesign.accent)
            .kraxlerGlassSurface(cornerRadius: 25, interactive: true)
            .padding()
    }
}

private extension ClimbingArea.AreaType {
    var symbolName: String {
        switch self {
        case .region:
            "mountain.2.fill"
        case .climbingArea:
            "figure.climbing"
        case .sector:
            "square.grid.2x2.fill"
        }
    }

    var markerColor: Color {
        switch self {
        case .region:
            .blue
        case .climbingArea:
            .orange
        case .sector:
            .green
        }
    }

    var annotationPriority: Int {
        switch self {
        case .region:
            0
        case .climbingArea:
            2
        case .sector:
            1
        }
    }
}

private struct MapAreaMarker: View {
    let area: ClimbingArea

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: area.type.symbolName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(area.type.markerColor, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 2)
                }
                .shadow(radius: 2, y: 1)

            Text(area.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.regularMaterial, in: Capsule())
        }
    }
}

private extension ClimbingArea {
    static let basCuvierPreview = ClimbingArea(
        id: "bas-cuvier",
        name: "Bas Cuvier",
        type: .climbingArea,
        location: GeoJSONPoint(type: "Point", coordinates: [2.63823, 48.44704])
    )

    static let roethelfelsPreview = ClimbingArea(
        id: "roethelfels",
        name: "Röthelfels",
        type: .climbingArea,
        location: GeoJSONPoint(type: "Point", coordinates: [11.24633, 49.74745])
    )
}

#Preview("Areas loaded") {
    MapScreen(
        initialAreas: [.basCuvierPreview, .roethelfelsPreview],
        loadsRemoteAreas: false
    )
}

#Preview("Loading error") {
    MapScreen(
        initialErrorMessage: "The preview API is unavailable.",
        loadsRemoteAreas: false
    )
}
