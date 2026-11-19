import CoreLocation
import Observation

enum LocationAccessAction: Equatable {
    case requestAuthorization
    case requestLocation
    case openSettings
}

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

    var accessAction: LocationAccessAction {
        Self.accessAction(for: authorizationStatus)
    }

    static func accessAction(for status: CLAuthorizationStatus) -> LocationAccessAction {
        switch status {
        case .notDetermined:
            .requestAuthorization
        case .authorizedAlways, .authorizedWhenInUse:
            .requestLocation
        case .denied, .restricted:
            .openSettings
        @unknown default:
            .openSettings
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
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
