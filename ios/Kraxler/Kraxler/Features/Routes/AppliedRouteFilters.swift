import SwiftUI

struct AppliedRouteFilters: View {
    @Binding var filters: RouteFilters

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if let discipline = filters.discipline {
                    filterChip(discipline.displayName) { filters.discipline = nil }
                }
                if filters.gradeSystem != nil {
                    filterChip(gradeFilterTitle) {
                        filters.gradeSystem = nil
                        filters.gradeMin = nil
                        filters.gradeMax = nil
                    }
                }
                ForEach(filters.styles.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) {
                    style in
                    filterChip(style.displayName) { filters.styles.remove(style) }
                }
                if filters.lengthMin != nil || filters.lengthMax != nil {
                    filterChip(lengthFilterTitle) {
                        filters.lengthMin = nil
                        filters.lengthMax = nil
                    }
                }
                if filters.pitchesMin != nil || filters.pitchesMax != nil {
                    filterChip(pitchFilterTitle) {
                        filters.pitchesMin = nil
                        filters.pitchesMax = nil
                    }
                }
            }
        }
        .scrollIndicators(.hidden)

    }

    private func filterChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "xmark").font(.caption2.bold())
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(title) filter")
    }

    private var gradeFilterTitle: String {
        switch (filters.gradeMin, filters.gradeMax) {
        case (.some(let minimum), .some(let maximum)): "\(minimum)–\(maximum)"
        case (.some(let minimum), .none): "\(minimum)+"
        case (.none, .some(let maximum)): "Up to \(maximum)"
        case (.none, .none): filters.gradeSystem?.displayName ?? "Grade"
        }
    }

    private var lengthFilterTitle: String {
        switch (filters.lengthMin, filters.lengthMax) {
        case (.some(let minimum), .some(let maximum)) where minimum == maximum:
            "\(minimum) m"
        case (.some(let minimum), .some(let maximum)):
            "\(minimum)–\(maximum) m"
        case (.some(let minimum), .none):
            "\(minimum)+ m"
        case (.none, .some(let maximum)):
            "Up to \(maximum) m"
        case (.none, .none):
            "Length"
        }
    }

    private var pitchFilterTitle: String {
        switch (filters.pitchesMin, filters.pitchesMax) {
        case (.some(let minimum), .some(let maximum)) where minimum == maximum:
            "\(minimum) \(minimum == 1 ? "pitch" : "pitches")"
        case (.some(let minimum), .some(let maximum)):
            "\(minimum)–\(maximum) pitches"
        case (.some(let minimum), .none):
            "\(minimum)+ pitches"
        case (.none, .some(let maximum)):
            "Up to \(maximum) \(maximum == 1 ? "pitch" : "pitches")"
        case (.none, .none):
            "Pitches"
        }
    }
}
