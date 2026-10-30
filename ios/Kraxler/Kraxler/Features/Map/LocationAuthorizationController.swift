import CoreLocation
import Observation

@MainActor
@Observable
final class LocationAuthorizationController: NSObject, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager

    private(set) var authorizationStatus: CLAuthorizationStatus

    override init() {
        let locationManager = CLLocationManager()
        self.locationManager = locationManager
        authorizationStatus = locationManager.authorizationStatus

        super.init()

        locationManager.delegate = self
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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
