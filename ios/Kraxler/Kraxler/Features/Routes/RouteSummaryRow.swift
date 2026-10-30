import SwiftUI

struct RouteSummaryRow: View {
    let route: ClimbingRoute
    var statusSymbol: String?
    var statusColor: Color = .orange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(route.name)
                    .font(.headline)

                Spacer()

                if let statusSymbol {
                    Image(systemName: statusSymbol)
                        .foregroundStyle(statusColor)
                        .accessibilityHidden(true)
                }

                Text(route.grade.value)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.tint)
            }

            HStack(spacing: 12) {
                Label(route.discipline.rawValue.capitalized, systemImage: "figure.climbing")

                if let lengthMeters = route.lengthMeters {
                    Label("\(lengthMeters.formatted()) m", systemImage: "ruler")
                }

                if let pitches = route.pitches, pitches > 1 {
                    Label("\(pitches) pitches", systemImage: "arrow.up.right")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !route.styles.isEmpty {
                Text(route.styles.map(\.displayName).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
