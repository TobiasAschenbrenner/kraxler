import CoreLocation
import Observation

@MainActor
@Observable
final class LocationAuthorizationController: NSObject, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var latestLocation: CLLocation?
    private(set) var locationUpdateID = 0

    override init() {
        let locationManager = CLLocationManager()
        self.locationManager = locationManager
        authorizationStatus = locationManager.authorizationStatus

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedAlways
            || authorizationStatus == .authorizedWhenInUse
    }

    func requestAuthorization() {
        guard authorizationStatus == .notDetermined else {
            return
        }

        locationManager.requestWhenInUseAuthorization()
    }

    func requestCurrentLocation() {
        guard isAuthorized else {
            requestAuthorization()
            return
        }

        locationManager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(
        _: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            return
        }

        latestLocation = location
        locationUpdateID += 1
    }

    func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        locationUpdateID += 1
    }
}
