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
