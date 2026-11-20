import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Kraxler

extension KraxlerTests {
    @Test
    func mapsAppearancePreferencesToColorSchemes() {
        #expect(AppAppearance.system.colorScheme == nil)
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
        #expect(AppAppearance.allCases.map(\.displayName) == ["System", "Light", "Dark"])
    }

    @Test
    func choosesLocationActionsForEveryAuthorizationState() {
        #expect(
            LocationAuthorizationController.accessAction(for: .notDetermined)
                == .requestAuthorization
        )
        #expect(
            LocationAuthorizationController.accessAction(for: .authorizedWhenInUse)
                == .requestLocation
        )
        #expect(
            LocationAuthorizationController.accessAction(for: .authorizedAlways)
                == .requestLocation
        )
        #expect(
            LocationAuthorizationController.accessAction(for: .denied)
                == .openSettings
        )
        #expect(
            LocationAuthorizationController.accessAction(for: .restricted)
                == .openSettings
        )
    }

    @Test
    func derivesBoundsFromVisibleMapCoordinates() {
        let bounds = MapBounds(
            southwest: CLLocationCoordinate2D(latitude: 48.25, longitude: 2.5),
            northeast: CLLocationCoordinate2D(latitude: 48.75, longitude: 3.5)
        )

        #expect(bounds.west == 2.5)
        #expect(bounds.south == 48.25)
        #expect(bounds.east == 3.5)
        #expect(bounds.north == 48.75)
    }

    @Test
    func createsACompactMapScaleWithinItsMaximumWidth() {
        let scale = CompactMapScale(
            latitude: 52.52,
            zoom: 14,
            maximumWidth: 120
        )

        #expect(scale.distanceMeters > 0)
        #expect(scale.width > 0)
        #expect(scale.width <= 120)
        #expect(!scale.label.isEmpty)
    }

    @Test
    func collapsesOverlappingHierarchyIntoOneClimbingAreaMarker() {
        let location = GeoJSONPoint(
            type: "Point",
            coordinates: [2.63823, 48.44704]
        )
        let region = ClimbingArea(
            id: "fontainebleau",
            name: "Fontainebleau",
            type: .region,
            location: location
        )
        let climbingArea = ClimbingArea(
            id: "cuvier",
            name: "Cuvier",
            type: .climbingArea,
            location: location
        )
        let sector = ClimbingArea(
            id: "bas-cuvier",
            name: "Bas Cuvier",
            type: .sector,
            location: location
        )
        let model = MapScreenModel(
            apiClient: APIClient(),
            initialAreas: [region, sector, climbingArea]
        )

        #expect(model.visibleAreas == [climbingArea])
    }

}
