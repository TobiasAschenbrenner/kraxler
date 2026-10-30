import Foundation

nonisolated struct ClimbingRoute: Codable, Hashable, Identifiable, Sendable {
    enum Discipline: String, Codable, Sendable {
        case sport
        case trad
        case bouldering
    }

    enum GradeSystem: String, Codable, Sendable {
        case uiaa
        case french
        case fontainebleau
        case vScale
    }

    enum Style: String, Codable, Sendable {
        case slab
        case vertical
        case overhang
        case roof
        case crack
        case chimney
        case arete
        case traverse
    }

    struct Grade: Codable, Hashable, Sendable {
        let system: GradeSystem
        let value: String
        let rank: Int
    }

    let id: String
    let areaId: String
    let name: String
    let location: GeoJSONPoint
    let discipline: Discipline
    let grade: Grade
    let styles: [Style]
    let lengthMeters: Double?
    let pitches: Int?
    let description: String?
}

extension ClimbingRoute.Discipline {
    var displayName: String {
        switch self {
        case .sport:
            "Sport climbing"
        case .trad:
            "Traditional climbing"
        case .bouldering:
            "Bouldering"
        }
    }
}

extension ClimbingRoute.GradeSystem {
    var displayName: String {
        switch self {
        case .uiaa:
            "UIAA"
        case .french:
            "French"
        case .fontainebleau:
            "Fontainebleau"
        case .vScale:
            "V-scale"
        }
    }
}
