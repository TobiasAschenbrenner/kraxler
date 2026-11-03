import Foundation
import SwiftData

@Model
final class OfflineAreaRecord {
    @Attribute(.unique) var areaID: String
    var name: String
    var typeRawValue: String
    var longitude: Double
    var latitude: Double
    var downloadedAt: Date
    var refreshedAt: Date
    var dataVersion: Int

    @Relationship(deleteRule: .cascade, inverse: \OfflineRouteRecord.area)
    var routes: [OfflineRouteRecord]

    init(
        area: ClimbingArea,
        downloadedAt: Date,
        refreshedAt: Date,
        dataVersion: Int = OfflineAreaManifest.currentDataVersion,
        routes: [OfflineRouteRecord] = []
    ) {
        areaID = area.id
        name = area.name
        typeRawValue = area.type.rawValue
        longitude = area.location.coordinates[0]
        latitude = area.location.coordinates[1]
        self.downloadedAt = downloadedAt
        self.refreshedAt = refreshedAt
        self.dataVersion = dataVersion
        self.routes = routes
    }

    var domainValue: ClimbingArea? {
        guard let type = ClimbingArea.AreaType(rawValue: typeRawValue) else {
            return nil
        }

        return ClimbingArea(
            id: areaID,
            name: name,
            type: type,
            location: GeoJSONPoint(
                type: "Point",
                coordinates: [longitude, latitude]
            )
        )
    }

    var manifest: OfflineAreaManifest? {
        guard let area = domainValue else {
            return nil
        }

        return OfflineAreaManifest(
            area: area,
            routeCount: routes.count,
            downloadedAt: downloadedAt,
            refreshedAt: refreshedAt,
            dataVersion: dataVersion
        )
    }

    func update(
        with area: ClimbingArea,
        refreshedAt: Date,
        dataVersion: Int
    ) {
        name = area.name
        typeRawValue = area.type.rawValue
        longitude = area.location.coordinates[0]
        latitude = area.location.coordinates[1]
        self.refreshedAt = refreshedAt
        self.dataVersion = dataVersion
    }
}

@Model
final class OfflineRouteRecord {
    var routeID: String
    var areaID: String
    var name: String
    var longitude: Double
    var latitude: Double
    var disciplineRawValue: String
    var gradeSystemRawValue: String
    var gradeValue: String
    var gradeRank: Int
    var stylesRawValue: String
    var lengthMeters: Double?
    var pitches: Int?
    var routeDescription: String?
    var area: OfflineAreaRecord?

    init(route: ClimbingRoute, area: OfflineAreaRecord? = nil) {
        routeID = route.id
        areaID = route.areaId
        name = route.name
        longitude = route.location.coordinates[0]
        latitude = route.location.coordinates[1]
        disciplineRawValue = route.discipline.rawValue
        gradeSystemRawValue = route.grade.system.rawValue
        gradeValue = route.grade.value
        gradeRank = route.grade.rank
        stylesRawValue = route.styles.map(\.rawValue).joined(separator: ",")
        lengthMeters = route.lengthMeters
        pitches = route.pitches
        routeDescription = route.description
        self.area = area
    }

    var domainValue: ClimbingRoute? {
        guard
            let discipline = ClimbingRoute.Discipline(rawValue: disciplineRawValue),
            let gradeSystem = ClimbingRoute.GradeSystem(rawValue: gradeSystemRawValue)
        else {
            return nil
        }

        let styles = stylesRawValue
            .split(separator: ",")
            .compactMap { ClimbingRoute.Style(rawValue: String($0)) }

        return ClimbingRoute(
            id: routeID,
            areaId: areaID,
            name: name,
            location: GeoJSONPoint(
                type: "Point",
                coordinates: [longitude, latitude]
            ),
            discipline: discipline,
            grade: ClimbingRoute.Grade(
                system: gradeSystem,
                value: gradeValue,
                rank: gradeRank
            ),
            styles: styles,
            lengthMeters: lengthMeters,
            pitches: pitches,
            description: routeDescription
        )
    }
}
