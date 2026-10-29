import CoreLocation
import Foundation

nonisolated struct GeoJSONPoint: Codable, Hashable, Sendable {
    let type: String
    let coordinates: [Double]

    var coordinate: CLLocationCoordinate2D {
        guard coordinates.count == 2 else {
            return CLLocationCoordinate2D()
        }

        return CLLocationCoordinate2D(
            latitude: coordinates[1],
            longitude: coordinates[0]
        )
    }
}
