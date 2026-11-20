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

    private let climbingRepository: ClimbingRepository
    private var lastLoadedBounds: MapBounds?
    private var requestID = UUID()

    private(set) var areas: [ClimbingArea]
    private(set) var loadStatus: LoadStatus
    private(set) var contentSource: ClimbingContentSource?

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
        climbingRepository = ClimbingRepository(apiClient: apiClient)
        areas = initialAreas
        contentSource = initialAreas.isEmpty ? nil : .remote

        if let initialErrorMessage {
            loadStatus = .failed(initialErrorMessage)
        } else if initialAreas.isEmpty {
            loadStatus = .idle
        } else {
            loadStatus = .loaded
        }
    }

    init(
        climbingRepository: ClimbingRepository,
        initialAreas: [ClimbingArea] = [],
        initialErrorMessage: String? = nil
    ) {
        self.climbingRepository = climbingRepository
        areas = initialAreas
        contentSource = initialAreas.isEmpty ? nil : .remote

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

        let currentRequest = UUID()
        requestID = currentRequest
        if areas.isEmpty { loadStatus = .loading }

        do {
            let response = try await climbingRepository.areas(in: bounds)
            guard !Task.isCancelled, requestID == currentRequest else {
                return
            }

            if response.source == .offline {
                // Keep already visible pins through brief outages, adding downloaded areas.
                let downloadedIDs = Set(response.value.map(\.id))
                areas = areas.filter { !downloadedIDs.contains($0.id) } + response.value
            } else {
                areas = response.value
            }
            contentSource = response.source
            lastLoadedBounds = bounds
            loadStatus = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, requestID == currentRequest,
                  (error as? URLError)?.code != .cancelled else { return }
            loadStatus = areas.isEmpty ? .failed(Self.message(for: error)) : .loaded
        }
    }

    private static func message(for error: Error) -> String {
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
