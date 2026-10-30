import Foundation

nonisolated struct RouteFilters: Equatable, Hashable, Sendable {
    var discipline: ClimbingRoute.Discipline?
    var gradeSystem: ClimbingRoute.GradeSystem?
    var gradeMin: String?
    var gradeMax: String?
    var styles: Set<ClimbingRoute.Style>
    var lengthMin: Int?
    var lengthMax: Int?
    var pitchesMin: Int?
    var pitchesMax: Int?

    init(
        discipline: ClimbingRoute.Discipline? = nil,
        gradeSystem: ClimbingRoute.GradeSystem? = nil,
        gradeMin: String? = nil,
        gradeMax: String? = nil,
        styles: Set<ClimbingRoute.Style> = [],
        lengthMin: Int? = nil,
        lengthMax: Int? = nil,
        pitchesMin: Int? = nil,
        pitchesMax: Int? = nil
    ) {
        self.discipline = discipline
        self.gradeSystem = gradeSystem
        self.gradeMin = gradeMin
        self.gradeMax = gradeMax
        self.styles = styles
        self.lengthMin = lengthMin
        self.lengthMax = lengthMax
        self.pitchesMin = pitchesMin
        self.pitchesMax = pitchesMax
    }

    var isEmpty: Bool {
        discipline == nil
            && gradeSystem == nil
            && styles.isEmpty
            && lengthMin == nil
            && lengthMax == nil
            && pitchesMin == nil
            && pitchesMax == nil
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []

        if let discipline {
            items.append(URLQueryItem(name: "discipline", value: discipline.rawValue))
        }
        if let gradeSystem {
            items.append(URLQueryItem(name: "gradeSystem", value: gradeSystem.rawValue))
        }
        if let gradeMin {
            items.append(URLQueryItem(name: "gradeMin", value: gradeMin))
        }
        if let gradeMax {
            items.append(URLQueryItem(name: "gradeMax", value: gradeMax))
        }
        if !styles.isEmpty {
            let value = styles.map(\.rawValue).sorted().joined(separator: ",")
            items.append(URLQueryItem(name: "style", value: value))
        }
        if let lengthMin {
            items.append(URLQueryItem(name: "lengthMin", value: String(lengthMin)))
        }
        if let lengthMax {
            items.append(URLQueryItem(name: "lengthMax", value: String(lengthMax)))
        }
        if let pitchesMin {
            items.append(URLQueryItem(name: "pitchesMin", value: String(pitchesMin)))
        }
        if let pitchesMax {
            items.append(URLQueryItem(name: "pitchesMax", value: String(pitchesMax)))
        }

        return items
    }
}
