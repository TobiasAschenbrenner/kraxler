import SwiftUI

struct AreaSummaryHeader: View {
    let area: ClimbingArea
    let routes: [ClimbingRoute]?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(area.name)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("area-detail-name")

            if let routes {
                HStack(spacing: 18) {
                    metadataItem("\(routes.count) routes", systemImage: "square.stack.3d.up")
                    if let gradeRange = gradeRange(for: routes) {
                        metadataItem(gradeRange, systemImage: "chart.bar")
                    }
                    if let discipline = dominantDiscipline(in: routes) {
                        metadataItem(discipline, systemImage: "figure.climbing")
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }
        }
        .padding(.top, 6)

    }

    private func metadataItem(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
    }

    private func gradeRange(for routes: [ClimbingRoute]) -> String? {
        guard
            let easiest = routes.min(by: { $0.grade.rank < $1.grade.rank }),
            let hardest = routes.max(by: { $0.grade.rank < $1.grade.rank })
        else { return nil }

        return easiest.grade.value == hardest.grade.value
            ? easiest.grade.value : "\(easiest.grade.value)–\(hardest.grade.value)"
    }

    private func dominantDiscipline(in routes: [ClimbingRoute]) -> String? {
        let discipline = Dictionary(grouping: routes, by: \.discipline)
            .max(by: { $0.value.count < $1.value.count })?.key
        guard let discipline else { return nil }
        return switch discipline {
        case .sport: "Mostly sport"
        case .trad: "Mostly trad"
        case .bouldering: "Mostly bouldering"
        }
    }
}
