import MapboxMaps
import SwiftUI

struct RouteMapPreview: View {
    let route: ClimbingRoute
    let source: ClimbingContentSource
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
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
            theme: .faded,
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
}
