import Foundation
import MapboxMaps

@MainActor
protocol OfflineMapStore: AnyObject {
    func downloadedAreaIDs() async throws -> Set<String>

    func downloadMap(
        for area: ClimbingArea,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws

    func removeMap(for areaID: String) async throws
}

enum MapboxOfflineMapStoreError: Error {
    case invalidStylePackOptions
    case invalidTileRegionOptions
}

@MainActor
final class MapboxOfflineMapStore: OfflineMapStore {
    private static let tileRegionPrefix = "kraxler-area-"
    private static let downloadRadius: CLLocationDistance = 5_000
    private static let styleProgressShare = 0.15

    private let offlineManager: OfflineManager
    private let tileStore: TileStore
    private var activeDownloads: [String: Cancelable] = [:]

    init(
        offlineManager: OfflineManager = OfflineManager(),
        tileStore: TileStore = .default
    ) {
        self.offlineManager = offlineManager
        self.tileStore = tileStore
    }

    func downloadedAreaIDs() async throws -> Set<String> {
        let regions = try await allTileRegions()
        return Set(regions.compactMap { Self.areaID(from: $0.id) })
    }

    func downloadMap(
        for area: ClimbingArea,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws {
        try await loadStylePack(for: area.id) { styleProgress in
            progress(styleProgress * Self.styleProgressShare)
        }

        try Task.checkCancellation()

        try await loadTileRegion(for: area) { tileProgress in
            progress(
                Self.styleProgressShare
                    + tileProgress * (1 - Self.styleProgressShare)
            )
        }

        progress(1)
    }

    func removeMap(for areaID: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            tileStore.removeRegion(forId: Self.tileRegionID(for: areaID)) {
                result in
                continuation.resume(with: result.map { _ in () })
            }
        }
    }

    private func loadStylePack(
        for areaID: String,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws {
        guard let options = StylePackLoadOptions(
            glyphsRasterizationMode: .ideographsRasterizedLocally,
            metadata: ["owner": "kraxler"]
        ) else {
            throw MapboxOfflineMapStoreError.invalidStylePackOptions
        }

        let downloadID = "style-\(areaID)"
        defer { activeDownloads[downloadID] = nil }

        try await withCheckedThrowingContinuation { continuation in
            activeDownloads[downloadID] = offlineManager.loadStylePack(
                for: .standard,
                loadOptions: options
            ) { update in
                let fraction = Self.fraction(
                    completed: update.completedResourceCount,
                    required: update.requiredResourceCount
                )
                Task { @MainActor in
                    progress(fraction)
                }
            } completion: { result in
                continuation.resume(with: result.map { _ in () })
            }
        }
    }

    private func loadTileRegion(
        for area: ClimbingArea,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws {
        let descriptor = offlineManager.createTilesetDescriptor(
            for: TilesetDescriptorOptions(
                styleURI: .standard,
                zoomRange: 9...16,
                tilesets: nil
            )
        )
        let geometry = Geometry.polygon(
            Polygon(
                center: area.location.coordinate,
                radius: Self.downloadRadius,
                vertices: 64
            )
        )

        guard let options = TileRegionLoadOptions(
            geometry: geometry,
            descriptors: [descriptor],
            metadata: ["areaID": area.id],
            acceptExpired: false
        ) else {
            throw MapboxOfflineMapStoreError.invalidTileRegionOptions
        }

        let downloadID = "tiles-\(area.id)"
        defer { activeDownloads[downloadID] = nil }

        try await withCheckedThrowingContinuation { continuation in
            activeDownloads[downloadID] = tileStore.loadTileRegion(
                forId: Self.tileRegionID(for: area.id),
                loadOptions: options
            ) { update in
                let fraction = Self.fraction(
                    completed: update.completedResourceCount,
                    required: update.requiredResourceCount
                )
                Task { @MainActor in
                    progress(fraction)
                }
            } completion: { result in
                continuation.resume(with: result.map { _ in () })
            }
        }
    }

    private func allTileRegions() async throws -> [TileRegion] {
        try await withCheckedThrowingContinuation { continuation in
            tileStore.allTileRegions { result in
                continuation.resume(with: result)
            }
        }
    }

    private static func tileRegionID(for areaID: String) -> String {
        tileRegionPrefix + areaID
    }

    private static func areaID(from tileRegionID: String) -> String? {
        guard tileRegionID.hasPrefix(tileRegionPrefix) else {
            return nil
        }
        return String(tileRegionID.dropFirst(tileRegionPrefix.count))
    }

    nonisolated private static func fraction(
        completed: UInt64,
        required: UInt64
    ) -> Double {
        guard required > 0 else {
            return 0
        }
        return min(max(Double(completed) / Double(required), 0), 1)
    }
}
