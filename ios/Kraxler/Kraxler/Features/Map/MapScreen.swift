import MapKit
import SwiftUI

struct MapScreen: View {
    private static let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 49.1, longitude: 6.9),
        span: MKCoordinateSpan(latitudeDelta: 2.1, longitudeDelta: 10.5)
    )

    private let apiClient: APIClient
    private let loadsRemoteAreas: Bool

    @Namespace private var mapScope
    @State private var model: MapScreenModel
    @State private var cameraPosition: MapCameraPosition
    @State private var requestedBounds: MapBounds
    @State private var selectedAreaID: String?
    @State private var selectedArea: ClimbingArea?

    init(
        apiClient: APIClient = APIClient(),
        initialAreas: [ClimbingArea] = [],
        initialErrorMessage: String? = nil,
        loadsRemoteAreas: Bool = true
    ) {
        self.apiClient = apiClient
        self.loadsRemoteAreas = loadsRemoteAreas
        _model = State(
            initialValue: MapScreenModel(
                apiClient: apiClient,
                initialAreas: initialAreas,
                initialErrorMessage: initialErrorMessage
            )
        )
        _cameraPosition = State(initialValue: .region(Self.initialRegion))
        _requestedBounds = State(initialValue: MapBounds(region: Self.initialRegion))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition, selection: $selectedAreaID, scope: mapScope) {
                ForEach(model.visibleAreas) { area in
                    Marker(
                        area.name,
                        systemImage: area.type.symbolName,
                        coordinate: area.location.coordinate
                    )
                    .tint(area.type.markerColor)
                    .tag(area.id)
                }

                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .mapScope(mapScope)
            .ignoresSafeArea(edges: .bottom)
            .onMapCameraChange(frequency: .onEnd) { context in
                requestedBounds = MapBounds(region: context.region)
            }

            titleCard

            statusOverlay
        }
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            MapUserLocationButton(scope: mapScope)
                .labelStyle(.iconOnly)
                .frame(width: 50, height: 50)
                .background(.regularMaterial, in: Circle())
                .padding()
                .accessibilityLabel("Show my location")
                .accessibilityIdentifier("map-user-location-button")
        }
        .task(id: requestedBounds) {
            guard loadsRemoteAreas else {
                return
            }
            await model.loadAreas(in: requestedBounds)
        }
        .onChange(of: selectedAreaID) { _, areaID in
            selectedArea = model.visibleAreas.first { $0.id == areaID }
        }
        .sheet(item: $selectedArea, onDismiss: {
            selectedAreaID = nil
        }) { area in
            AreaDetailSheet(area: area, apiClient: apiClient)
        }
    }

    private var titleCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kraxler")
                    .font(.title2.bold())

                Text(areaCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "mountain.2.fill")
                .font(.title2)
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch model.loadStatus {
        case .idle, .loaded:
            if model.visibleAreas.isEmpty, model.loadStatus == .loaded {
                statusCard {
                    Label("No climbing areas in this view", systemImage: "map")
                }
            }

        case .loading:
            statusCard {
                ProgressView("Loading climbing areas…")
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

    private var areaCountText: String {
        switch model.loadStatus {
        case .loading where model.visibleAreas.isEmpty:
            "Finding climbing areas…"
        default:
            "\(model.visibleAreas.count) climbing \(model.visibleAreas.count == 1 ? "area" : "areas") in view"
        }
    }
}

private extension ClimbingArea.AreaType {
    var symbolName: String {
        switch self {
        case .region:
            "mountain.2.fill"
        case .climbingArea:
            "mappin.circle.fill"
        case .sector:
            "figure.climbing"
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
