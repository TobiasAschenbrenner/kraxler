import SwiftUI

struct RouteSummaryRow: View {
    let route: ClimbingRoute
    var statusSymbol: String?
    var statusColor: Color = .orange

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(route.grade.value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .frame(minWidth: 42, minHeight: 42)
                .padding(.horizontal, 4)
                .background(
                    KraxlerDesign.accent.gradient,
                    in: RoundedRectangle(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(route.name)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    if let statusSymbol {
                        Image(systemName: statusSymbol)
                            .foregroundStyle(statusColor)
                            .accessibilityHidden(true)
                    }
                }

                HStack(spacing: 10) {
                    Label(route.discipline.displayName, systemImage: "figure.climbing")

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
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
