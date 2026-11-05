import SwiftUI

struct RouteSummaryRow: View {
    let route: ClimbingRoute
    var statusSymbol: String?
    var statusColor: Color = KraxlerDesign.accent

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(route.name)
                        .font(.headline)
                        .lineLimit(2)

                    Text(route.grade.value)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(KraxlerDesign.accent)
                }

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let statusSymbol {
                Image(systemName: statusSymbol)
                    .foregroundStyle(statusColor)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var detailText: String {
        var details = [route.discipline.displayName]
        if let lengthMeters = route.lengthMeters {
            details.append("\(lengthMeters.formatted()) m")
        }
        if let pitches = route.pitches, pitches > 1 {
            details.append("\(pitches) pitches")
        }
        return details.joined(separator: " · ")
    }
}
