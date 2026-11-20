import Foundation

nonisolated struct LibraryRouteGroup: Identifiable {
    let id: String
    let areaName: String
    let routes: [PersonalRoute]

    static func grouping(_ routes: [PersonalRoute]) -> [LibraryRouteGroup] {
        Dictionary(grouping: routes, by: { $0.climbingAreaId ?? $0.route.areaId })
            .map { areaID, routes in
                LibraryRouteGroup(
                    id: areaID,
                    areaName: routes.compactMap(\.areaName).first ?? "Other areas",
                    routes: routes.sorted {
                        $0.route.name.localizedStandardCompare($1.route.name) == .orderedAscending
                    }
                )
            }
            .sorted {
                let order = $0.areaName.localizedStandardCompare($1.areaName)
                return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
            }
    }
}
