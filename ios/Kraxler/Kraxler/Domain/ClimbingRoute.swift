import Foundation

nonisolated struct ClimbingRoute: Codable, Hashable, Identifiable, Sendable {
    enum Discipline: String, CaseIterable, Codable, Sendable {
        case sport
        case trad
        case bouldering
    }

    enum GradeSystem: String, CaseIterable, Codable, Sendable {
        case uiaa
        case french
        case fontainebleau
        case vScale
    }

    enum Style: String, CaseIterable, Codable, Sendable {
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

    var values: [String] {
        switch self {
        case .uiaa:
            [
                "1", "2", "2+", "3-", "3", "3+", "4-", "4", "4+", "5-", "5",
                "5+", "6-", "6", "6+", "7-", "7", "7+", "8-", "8", "8+", "9-",
                "9", "9+", "10-", "10", "10+", "11-", "11", "11+", "12-", "12",
            ]
        case .french:
            [
                "1", "2", "3", "4a", "4b", "4c", "5a", "5b", "5c", "6a", "6a+",
                "6b", "6b+", "6c", "6c+", "7a", "7a+", "7b", "7b+", "7c", "7c+",
                "8a", "8a+", "8b", "8b+", "8c", "8c+", "9a", "9a+", "9b", "9b+",
                "9c", "9c+",
            ]
        case .fontainebleau:
            [
                "1A", "1B", "1C", "2A", "2B", "2C", "3A", "3B", "3C", "4A", "4A+",
                "4B", "4B+", "4C", "4C+", "5A", "5A+", "5B", "5B+", "5C", "5C+",
                "6A", "6A+", "6B", "6B+", "6C", "6C+", "7A", "7A+", "7B", "7B+",
                "7C", "7C+", "8A", "8A+", "8B", "8B+", "8C", "8C+", "9A",
            ]
        case .vScale:
            [
                "VB", "V0-", "V0", "V0+", "V1", "V2", "V3", "V4", "V5", "V6",
                "V7", "V8", "V9", "V10", "V11", "V12", "V13", "V14", "V15", "V16",
                "V17",
            ]
        }
    }
}

extension ClimbingRoute.Style {
    var displayName: String {
        switch self {
        case .slab:
            "Slab"
        case .vertical:
            "Vertical"
        case .overhang:
            "Overhang"
        case .roof:
            "Roof"
        case .crack:
            "Crack"
        case .chimney:
            "Chimney"
        case .arete:
            "Arête"
        case .traverse:
            "Traverse"
        }
    }
}
