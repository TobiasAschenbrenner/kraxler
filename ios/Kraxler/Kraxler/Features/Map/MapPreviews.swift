import SwiftUI

#if DEBUG
    extension ClimbingArea {
        fileprivate static let basCuvierPreview = ClimbingArea(
            id: "bas-cuvier",
            name: "Bas Cuvier",
            type: .climbingArea,
            location: GeoJSONPoint(type: "Point", coordinates: [2.63823, 48.44704])
        )

        fileprivate static let roethelfelsPreview = ClimbingArea(
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

#endif
