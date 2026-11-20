import CoreLocation
import MapboxMaps
import SwiftUI

nonisolated struct CompactMapScale: Equatable, Sendable {
    let distanceMeters: Double
    let width: CGFloat

    init(
        latitude: CLLocationDegrees,
        zoom: CGFloat,
        maximumWidth: CGFloat = 120
    ) {
        let metersPerPoint = Projection.metersPerPoint(
            for: latitude,
            zoom: zoom
        )
        let maximumDistance = max(metersPerPoint * Double(maximumWidth), 1)
        let magnitude = pow(10, floor(log10(maximumDistance)))
        let normalizedDistance = maximumDistance / magnitude
        let factor =
            [5.0, 2.5, 2.0, 1.0]
            .first(where: { $0 <= normalizedDistance }) ?? 1
        let distance = factor * magnitude

        distanceMeters = distance
        width = min(maximumWidth, CGFloat(distance / metersPerPoint))
    }

    var label: String {
        if distanceMeters >= 1_000 {
            let kilometers = distanceMeters / 1_000
            return kilometers.rounded() == kilometers
                ? "\(Int(kilometers)) km"
                : "\(kilometers.formatted(.number.precision(.fractionLength(1)))) km"
        }

        return "\(Int(distanceMeters.rounded())) m"
    }
}

struct CompactMapScaleView: View {
    let scale: CompactMapScale

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text("0")
                Spacer(minLength: 8)
                Text(scale.label)
            }

            Capsule()
                .fill(.primary)
                .frame(height: 2)
        }
        .font(.caption2.monospacedDigit().weight(.semibold))
        .frame(width: scale.width)
        .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map scale \(scale.label)")
    }
}
