import MapKit

extension MapBounds {
    init(region: MKCoordinateRegion) {
        let halfLatitudeDelta = region.span.latitudeDelta / 2
        let halfLongitudeDelta = region.span.longitudeDelta / 2

        self.init(
            west: max(-180, region.center.longitude - halfLongitudeDelta),
            south: max(-90, region.center.latitude - halfLatitudeDelta),
            east: min(180, region.center.longitude + halfLongitudeDelta),
            north: min(90, region.center.latitude + halfLatitudeDelta)
        )
    }
}
