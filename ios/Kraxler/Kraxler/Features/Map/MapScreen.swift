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

    @Environment(\.colorScheme) private var colorScheme
    @State private var model: MapScreenModel
    @State private var locationAuthorization = LocationAuthorizationController()
    @State private var viewport: Viewport
    @State private var requestedBounds: MapBounds
    @State private var sheetDestination: SheetDestination?
    @State private var pendingAreaFromSearch: ClimbingArea?
    @State private var selectedAreaID: String?

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
                                    selectedAreaID = area.id
                                    sheetDestination = .area(area)
                                } label: {
                                    MapAreaMarker(isSelected: selectedAreaID == area.id)
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
                    .mapStyle(mapStyle)
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
                    .ignoresSafeArea()
                }
            }

            mapHeader

            statusOverlay
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
            selectedAreaID = nil
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

    private var mapStyle: MapStyle {
        .standard(
            theme: .monochrome,
            lightPreset: colorScheme == .dark ? .night : .day,
            showPointOfInterestLabels: false,
            showTransitLabels: false,
            showPlaceLabels: true,
            showRoadLabels: true,
            show3dObjects: false
        )
    }

    @ViewBuilder
    private var locationControl: some View {
        if locationAuthorization.isAuthorized {
            Button {
                viewport = .followPuck(zoom: 14, bearing: .heading)
            } label: {
                Image(systemName: "location.fill")
            }
            .buttonStyle(KraxlerIconButtonStyle(foregroundStyle: KraxlerDesign.accent))
            .accessibilityLabel("Show my location")
            .accessibilityIdentifier("map-user-location-button")
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
            .buttonStyle(KraxlerIconButtonStyle(foregroundStyle: KraxlerDesign.accent))
        }
    }

    private var mapHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            HStack(spacing: 9) {
                Text("Kraxler")
                    .font(.system(.title, design: .rounded, weight: .bold))

                KraxlerBrandMark(size: 38)
            }
            .padding(.top, 8)

            Spacer()

            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    Button {
                        sheetDestination = .search
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(KraxlerIconButtonStyle())
                    .accessibilityLabel("Search climbing areas and routes")
                    .accessibilityIdentifier("map-search-button")

                    locationControl
                }
            }
        }
        .padding(.horizontal, KraxlerDesign.pagePadding)
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
            .padding(.top, 156)
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
        .padding(.top, 156)
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
            selectedAreaID = area.id
            sheetDestination = .area(area)
        }
    }
}

private extension ClimbingArea.AreaType {
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
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(KraxlerDesign.accent.opacity(0.22))
                    .frame(width: 32, height: 32)

                Circle()
                    .stroke(KraxlerDesign.accent, lineWidth: 3)
                    .frame(width: 22, height: 22)
            }

            Circle()
                .fill(isSelected ? KraxlerDesign.accent : Color(.systemGray3))
                .frame(width: isSelected ? 10 : 9, height: isSelected ? 10 : 9)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.9), lineWidth: 1.5)
                }
                .shadow(color: .black.opacity(0.24), radius: 3, y: 1)
        }
        .frame(width: 34, height: 34)
        .animation(.snappy(duration: 0.22), value: isSelected)
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
