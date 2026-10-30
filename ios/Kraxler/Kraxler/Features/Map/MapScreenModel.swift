import CoreLocation
import Foundation
import Observation

@Observable
@MainActor
final class MapScreenModel {
    enum LoadStatus: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private let apiClient: APIClient
    private var lastLoadedBounds: MapBounds?

    private(set) var areas: [ClimbingArea]
    private(set) var loadStatus: LoadStatus

    var visibleAreas: [ClimbingArea] {
        var areasByLocation: [MapLocationKey: ClimbingArea] = [:]

        for area in areas {
            let key = MapLocationKey(coordinate: area.location.coordinate)

            guard let currentArea = areasByLocation[key] else {
                areasByLocation[key] = area
                continue
            }

            if area.type.mapMarkerPriority > currentArea.type.mapMarkerPriority {
                areasByLocation[key] = area
            }
        }

        return areasByLocation.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    init(
        apiClient: APIClient,
        initialAreas: [ClimbingArea] = [],
        initialErrorMessage: String? = nil
    ) {
        self.apiClient = apiClient
        areas = initialAreas

        if let initialErrorMessage {
            loadStatus = .failed(initialErrorMessage)
        } else if initialAreas.isEmpty {
            loadStatus = .idle
        } else {
            loadStatus = .loaded
        }
    }

    func loadAreas(in bounds: MapBounds, force: Bool = false) async {
        guard force || bounds != lastLoadedBounds else {
            return
        }

        if areas.isEmpty {
            loadStatus = .loading
        }

        do {
            let loadedAreas = try await apiClient.areas(in: bounds)
            guard !Task.isCancelled else {
                return
            }

            areas = loadedAreas
            lastLoadedBounds = bounds
            loadStatus = .loaded
        } catch is CancellationError {
            return
        } catch {
            loadStatus = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError,
           [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost].contains(urlError.code) {
            return "The Kraxler API is not reachable. Make sure the local backend is running."
        }

        return "Climbing areas could not be loaded. Please try again."
    }
}

private struct MapLocationKey: Hashable {
    private static let precision = 100_000.0

    let latitude: Int
    let longitude: Int

    init(coordinate: CLLocationCoordinate2D) {
        latitude = Int((coordinate.latitude * Self.precision).rounded())
        longitude = Int((coordinate.longitude * Self.precision).rounded())
    }
}

private extension ClimbingArea.AreaType {
    var mapMarkerPriority: Int {
        switch self {
        case .region:
            1
        case .sector:
            2
        case .climbingArea:
            3
        }
    }
}
