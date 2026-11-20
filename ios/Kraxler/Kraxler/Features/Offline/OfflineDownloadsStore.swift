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
    private(set) var downloadedMapAreaIDs: Set<String> = []
    private(set) var downloadedTopoAreaIDs: Set<String> = []
    private(set) var downloadProgressByAreaID: [String: Double] = [:]

    private let climbingRepository: ClimbingRepository
    private let offlineMapStore: OfflineMapStore

    var downloadedManifests: [OfflineAreaManifest] {
        manifestsByAreaID.values.sorted {
            $0.area.name.localizedStandardCompare($1.area.name) == .orderedAscending
        }
    }

    init(
        climbingRepository: ClimbingRepository,
        offlineMapStore: OfflineMapStore
    ) {
        self.climbingRepository = climbingRepository
        self.offlineMapStore = offlineMapStore
    }

    func load() async {
        do {
            manifestsByAreaID = Dictionary(
                uniqueKeysWithValues: try climbingRepository
                    .offlineManifests()
                    .map { ($0.area.id, $0) }
            )
        } catch {
            manifestsByAreaID = [:]
        }

        downloadedTopoAreaIDs = Set(downloadedManifests.filter {
            climbingRepository.hasDownloadedTopos(for: $0)
        }.map(\.id))

        do {
            downloadedMapAreaIDs = try await offlineMapStore.downloadedAreaIDs()
        } catch {
            downloadedMapAreaIDs = []
        }
    }

    func manifest(for areaID: String) -> OfflineAreaManifest? {
        manifestsByAreaID[areaID]
    }

    func operation(for areaID: String) -> Operation {
        operationsByAreaID[areaID] ?? .idle
    }

    func downloadProgress(for areaID: String) -> Double? {
        downloadProgressByAreaID[areaID]
    }

    func isAvailableOffline(areaID: String) -> Bool {
        manifestsByAreaID[areaID] != nil
            && downloadedMapAreaIDs.contains(areaID)
            && downloadedTopoAreaIDs.contains(areaID)
    }

    func hasIncompleteDownload(areaID: String) -> Bool {
        hasAnyDownload(areaID: areaID) && !isAvailableOffline(areaID: areaID)
    }

    func hasAnyDownload(areaID: String) -> Bool {
        manifestsByAreaID[areaID] != nil || downloadedMapAreaIDs.contains(areaID)
    }

    func download(_ area: ClimbingArea) async {
        guard !operation(for: area.id).isInProgress else {
            return
        }

        operationsByAreaID[area.id] = .downloading
        downloadProgressByAreaID[area.id] = 0
        let hadMapBeforeDownload = downloadedMapAreaIDs.contains(area.id)

        do {
            try await offlineMapStore.downloadMap(for: area) { [weak self] progress in
                self?.downloadProgressByAreaID[area.id] = progress * 0.8
            }
            downloadedMapAreaIDs.insert(area.id)

            try Task.checkCancellation()
            let manifest = try await climbingRepository.download(area) { [weak self] progress in
                self?.downloadProgressByAreaID[area.id] = 0.8 + progress * 0.2
            }
            try Task.checkCancellation()
            manifestsByAreaID[area.id] = manifest
            downloadedTopoAreaIDs.insert(area.id)
            operationsByAreaID[area.id] = .idle
            downloadProgressByAreaID[area.id] = nil
        } catch is CancellationError {
            if !hadMapBeforeDownload {
                try? await offlineMapStore.removeMap(for: area.id)
                downloadedMapAreaIDs.remove(area.id)
            }
            operationsByAreaID[area.id] = .idle
            downloadProgressByAreaID[area.id] = nil
        } catch {
            if !hadMapBeforeDownload {
                try? await offlineMapStore.removeMap(for: area.id)
                downloadedMapAreaIDs.remove(area.id)
            }
            operationsByAreaID[area.id] = .failed(
                "The area could not be downloaded. Check your connection and try again."
            )
            downloadProgressByAreaID[area.id] = nil
        }
    }

    func remove(areaID: String) async {
        guard !operation(for: areaID).isInProgress else {
            return
        }

        operationsByAreaID[areaID] = .removing

        do {
            if downloadedMapAreaIDs.contains(areaID) {
                try await offlineMapStore.removeMap(for: areaID)
                downloadedMapAreaIDs.remove(areaID)
            }
            try climbingRepository.removeDownload(for: areaID)
            manifestsByAreaID[areaID] = nil
            downloadedTopoAreaIDs.remove(areaID)
            operationsByAreaID[areaID] = .idle
        } catch {
            operationsByAreaID[areaID] = .failed(
                "The downloaded area could not be removed. Please try again."
            )
        }
    }
}
