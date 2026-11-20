import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

struct MapScreen: View {
    private enum SheetDestination: Identifiable {
        case area(ClimbingArea)

        var id: String {
            switch self {
            case .area(let area):
                "area-\(area.id)"
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
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: MapScreenModel
    @State private var locationAuthorization = LocationAuthorizationController()
    @State private var viewport: Viewport
    @State private var requestedBounds: MapBounds
    @State private var sheetDestination: SheetDestination?
    @State private var isSearchPresented = false
    @State private var pendingAreaFromSearch: ClimbingArea?
    @State private var selectedAreaID: String?
    @State private var isLocationFocusPending = false
    @State private var hasRequestedInitialLocation = false
    @State private var showsLocationSettingsAlert = false
    @State private var mapScale: CompactMapScale

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
        _mapScale = State(
            initialValue: CompactMapScale(
                latitude: Self.initialCenter.latitude,
                zoom: 4.8
            )
        )
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
                    .ornamentOptions(mapOrnamentOptions)
                    .onMapIdle { _ in
                        updateVisibleBounds(
                            using: proxy,
                            mapSize: geometry.size
                        )
                        updateMapScale(using: proxy)
                    }
                    .ignoresSafeArea()
                }
            }

            MapHeader(
                scale: mapScale,
                locationIcon: locationControlIcon,
                locationLabel: locationControlAccessibilityLabel,
                locationIdentifier: locationAuthorization.isAuthorized
                    ? "map-user-location-button" : "map-location-permission-button",
                onSearch: { isSearchPresented = true },
                onLocate: handleLocationControlTapped
            )

            MapLoadStatusView(status: model.loadStatus) {
                Task { await model.loadAreas(in: requestedBounds, force: true) }
            }
        }
        .overlay(alignment: .bottom) {
            if climbingRepository.showsOfflineIndicator {
                Label("Offline", systemImage: "wifi.slash")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                    .accessibilityIdentifier("map-offline-indicator")
                    .allowsHitTesting(false)
                    .padding(.bottom, 10)
            }
        }
        .task(
            id: MapRequestKey(
                bounds: requestedBounds, connectionRevision: climbingRepository.connectionRevision)
        ) {
            guard loadsRemoteAreas else {
                return
            }
            await model.loadAreas(in: requestedBounds, force: true)
        }
        .task {
            requestInitialUserLocation()
        }
        .onChange(of: locationAuthorization.isAuthorized) { _, isAuthorized in
            guard isAuthorized else {
                return
            }

            focusOnUserLocation()
        }
        .onChange(of: locationAuthorization.locationUpdateID) {
            guard isLocationFocusPending else {
                return
            }

            if let location = locationAuthorization.latestLocation {
                focusMap(on: location)
            }
            isLocationFocusPending = false
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else {
                return
            }

            locationAuthorization.refreshAuthorizationStatus()
        }
        .alert("Location Off", isPresented: $showsLocationSettingsAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Settings") {
                openLocationSettings()
            }
        } message: {
            Text("Allow location access in Settings.")
        }
        .fullScreenCover(
            item: $sheetDestination,
            onDismiss: {
                selectedAreaID = nil
                presentPendingAreaFromSearch()
            }
        ) { destination in
            switch destination {
            case .area(let area):
                AreaDetailSheet(
                    area: area,
                    climbingRepository: climbingRepository,
                    personalRoutesStore: personalRoutesStore,
                    offlineDownloadsStore: offlineDownloadsStore
                )
            }
        }
        .fullScreenCover(
            isPresented: $isSearchPresented,
            onDismiss: {
                presentPendingAreaFromSearch()
            }
        ) {
            MapSearchSheet(
                climbingRepository: climbingRepository,
                personalRoutesStore: personalRoutesStore
            ) { area in
                focusMap(on: area)
                pendingAreaFromSearch = area
            }
        }
    }

    private var mapStyle: MapStyle {
        .standard(
            theme: .faded,
            lightPreset: colorScheme == .dark ? .night : .day,
            showPointOfInterestLabels: false,
            showTransitLabels: false,
            showPlaceLabels: true,
            showRoadLabels: true,
            show3dObjects: false
        )
    }

    private var mapOrnamentOptions: OrnamentOptions {
        OrnamentOptions(
            scaleBar: ScaleBarViewOptions(
                visibility: .hidden
            ),
            compass: CompassViewOptions(
                position: .bottomRight,
                margins: CGPoint(x: 18, y: 16),
                visibility: .visible
            ),
            logo: LogoViewOptions(
                position: .bottomLeading,
                margins: CGPoint(x: 16, y: 12)
            ),
            attributionButton: AttributionButtonOptions(
                position: .bottomLeading,
                margins: CGPoint(x: 16, y: 44),
                tintColor: .label
            )
        )
    }

    private func focusMap(on area: ClimbingArea) {
        viewport = .camera(
            center: area.location.coordinate,
            zoom: 13.5
        )
    }

    private func focusOnUserLocation() {
        isLocationFocusPending = true

        if let location = locationAuthorization.latestLocation {
            focusMap(on: location)
        }

        locationAuthorization.requestCurrentLocation()
    }

    private func requestInitialUserLocation() {
        guard !hasRequestedInitialLocation else {
            return
        }

        hasRequestedInitialLocation = true

        guard locationAuthorization.accessAction != .openSettings else {
            return
        }

        focusOnUserLocation()
    }

    private func handleLocationControlTapped() {
        switch locationAuthorization.accessAction {
        case .requestAuthorization, .requestLocation:
            focusOnUserLocation()
        case .openSettings:
            showsLocationSettingsAlert = true
        }
    }

    private var locationControlIcon: String {
        switch locationAuthorization.accessAction {
        case .requestAuthorization:
            "location"
        case .requestLocation:
            "location.fill"
        case .openSettings:
            "location.slash"
        }
    }

    private var locationControlAccessibilityLabel: String {
        switch locationAuthorization.accessAction {
        case .requestAuthorization:
            "Allow location access"
        case .requestLocation:
            "Show my location"
        case .openSettings:
            "Open location settings"
        }
    }

    private func openLocationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(settingsURL)
    }

    private func focusMap(on location: CLLocation) {
        viewport = .camera(
            center: location.coordinate,
            zoom: 14
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

    private func updateMapScale(using proxy: MapProxy) {
        guard let map = proxy.map else {
            return
        }

        let camera = map.cameraState
        mapScale = CompactMapScale(
            latitude: camera.center.latitude,
            zoom: camera.zoom
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

extension ClimbingArea.AreaType {
    fileprivate var annotationPriority: Int {
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

private struct MapRequestKey: Hashable {
    let bounds: MapBounds
    let connectionRevision: Int
}
