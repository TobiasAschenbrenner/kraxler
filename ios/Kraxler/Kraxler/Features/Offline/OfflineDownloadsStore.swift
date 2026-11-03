import Foundation
import Observation

@MainActor
@Observable
final class OfflineDownloadsStore {
    enum Operation: Equatable {
        case idle
        case downloading
        case removing
        case failed(String)

        var isInProgress: Bool {
            self == .downloading || self == .removing
        }
    }

    private(set) var manifestsByAreaID: [String: OfflineAreaManifest] = [:]
    private(set) var operationsByAreaID: [String: Operation] = [:]

    private let climbingRepository: ClimbingRepository

    init(climbingRepository: ClimbingRepository) {
        self.climbingRepository = climbingRepository
    }

    func load() {
        do {
            manifestsByAreaID = Dictionary(
                uniqueKeysWithValues: try climbingRepository
                    .offlineManifests()
                    .map { ($0.area.id, $0) }
            )
        } catch {
            manifestsByAreaID = [:]
        }
    }

    func manifest(for areaID: String) -> OfflineAreaManifest? {
        manifestsByAreaID[areaID]
    }

    func operation(for areaID: String) -> Operation {
        operationsByAreaID[areaID] ?? .idle
    }

    func download(_ area: ClimbingArea) async {
        guard !operation(for: area.id).isInProgress else {
            return
        }

        operationsByAreaID[area.id] = .downloading

        do {
            let manifest = try await climbingRepository.download(area)
            guard !Task.isCancelled else {
                return
            }
            manifestsByAreaID[area.id] = manifest
            operationsByAreaID[area.id] = .idle
        } catch is CancellationError {
            operationsByAreaID[area.id] = .idle
        } catch {
            operationsByAreaID[area.id] = .failed(
                "The area could not be downloaded. Check your connection and try again."
            )
        }
    }

    func remove(areaID: String) {
        guard !operation(for: areaID).isInProgress else {
            return
        }

        operationsByAreaID[areaID] = .removing

        do {
            try climbingRepository.removeDownload(for: areaID)
            manifestsByAreaID[areaID] = nil
            operationsByAreaID[areaID] = .idle
        } catch {
            operationsByAreaID[areaID] = .failed(
                "The downloaded area could not be removed. Please try again."
            )
        }
    }
}
