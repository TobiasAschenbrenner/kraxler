import Foundation
import SwiftData

@MainActor
final class OfflineClimbingStore {
    private let context: ModelContext

    init(modelContainer: ModelContainer) {
        context = ModelContext(modelContainer)
        context.autosaveEnabled = false
    }

    func manifests() throws -> [OfflineAreaManifest] {
        try areaRecords()
            .compactMap(\.manifest)
            .sorted { $0.area.name.localizedStandardCompare($1.area.name) == .orderedAscending }
    }

    func manifest(for areaID: String) throws -> OfflineAreaManifest? {
        try areaRecord(for: areaID)?.manifest
    }

    func save(
        area: ClimbingArea,
        routes: [ClimbingRoute],
        at date: Date = .now,
        dataVersion: Int = OfflineAreaManifest.currentDataVersion
    ) throws {
        let savedAreaRecord: OfflineAreaRecord

        if let existingRecord = try areaRecord(for: area.id) {
            savedAreaRecord = existingRecord
            savedAreaRecord.update(
                with: area,
                refreshedAt: date,
                dataVersion: dataVersion
            )
            savedAreaRecord.routes.forEach(context.delete)
            savedAreaRecord.routes.removeAll()
        } else {
            savedAreaRecord = OfflineAreaRecord(
                area: area,
                downloadedAt: date,
                refreshedAt: date,
                dataVersion: dataVersion
            )
            context.insert(savedAreaRecord)
        }

        for route in routes {
            let routeRecord = OfflineRouteRecord(route: route, area: savedAreaRecord)
            savedAreaRecord.routes.append(routeRecord)
        }

        try context.save()
    }

    func remove(areaID: String) throws {
        guard let record = try areaRecord(for: areaID) else {
            return
        }

        context.delete(record)
        try context.save()
    }

    func areas(in bounds: MapBounds) throws -> [ClimbingArea] {
        try areaRecords()
            .compactMap(\.domainValue)
            .filter { area in
                let longitude = area.location.coordinates[0]
                let latitude = area.location.coordinates[1]
                return longitude >= bounds.west
                    && longitude <= bounds.east
                    && latitude >= bounds.south
                    && latitude <= bounds.north
            }
    }

    func routes(for areaID: String) throws -> [ClimbingRoute] {
        guard let area = try areaRecord(for: areaID) else {
            return []
        }

        return area.routes
            .compactMap(\.domainValue)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func route(id routeID: String) throws -> ClimbingRoute? {
        var descriptor = FetchDescriptor<OfflineRouteRecord>(
            predicate: #Predicate { $0.routeID == routeID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.domainValue
    }

    func search(_ query: String) throws -> SearchResults {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let areas = try areaRecords()
            .compactMap(\.domainValue)
            .filter { $0.name.localizedCaseInsensitiveContains(normalizedQuery) }

        let routes = try context.fetch(FetchDescriptor<OfflineRouteRecord>())
            .compactMap(\.domainValue)
            .filter { $0.name.localizedCaseInsensitiveContains(normalizedQuery) }

        return SearchResults(areas: areas, routes: routes)
    }

    private func areaRecords() throws -> [OfflineAreaRecord] {
        try context.fetch(FetchDescriptor<OfflineAreaRecord>())
    }

    private func areaRecord(for areaID: String) throws -> OfflineAreaRecord? {
        var descriptor = FetchDescriptor<OfflineAreaRecord>(
            predicate: #Predicate { $0.areaID == areaID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
