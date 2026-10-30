import SwiftUI

struct RouteFilterSheet: View {
    let onApply: (RouteFilters) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var filters: RouteFilters
    @State private var usesLengthRange: Bool
    @State private var minimumLength: Int
    @State private var maximumLength: Int
    @State private var usesPitchRange: Bool
    @State private var minimumPitches: Int
    @State private var maximumPitches: Int

    init(filters: RouteFilters, onApply: @escaping (RouteFilters) -> Void) {
        self.onApply = onApply
        _filters = State(initialValue: filters)
        _usesLengthRange = State(
            initialValue: filters.lengthMin != nil || filters.lengthMax != nil
        )
        _minimumLength = State(initialValue: filters.lengthMin ?? 1)
        _maximumLength = State(initialValue: filters.lengthMax ?? 50)
        _usesPitchRange = State(
            initialValue: filters.pitchesMin != nil || filters.pitchesMax != nil
        )
        _minimumPitches = State(initialValue: filters.pitchesMin ?? 1)
        _maximumPitches = State(initialValue: filters.pitchesMax ?? 10)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Climb") {
                    Picker("Discipline", selection: $filters.discipline) {
                        Text("Any discipline")
                            .tag(nil as ClimbingRoute.Discipline?)
                        ForEach(ClimbingRoute.Discipline.allCases, id: \.self) { discipline in
                            Text(discipline.displayName)
                                .tag(discipline as ClimbingRoute.Discipline?)
                        }
                    }
                }

                gradeSection
                styleSection
                lengthSection
                pitchSection
            }
            .navigationTitle("Route filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyFilters()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        clearFilters()
                    }
                    .disabled(filters.isEmpty && !usesLengthRange && !usesPitchRange)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var gradeSection: some View {
        Section("Grade") {
            Picker("Grading system", selection: $filters.gradeSystem) {
                Text("Any system")
                    .tag(nil as ClimbingRoute.GradeSystem?)
                ForEach(ClimbingRoute.GradeSystem.allCases, id: \.self) { system in
                    Text(system.displayName)
                        .tag(system as ClimbingRoute.GradeSystem?)
                }
            }
            .onChange(of: filters.gradeSystem) { oldValue, newValue in
                guard oldValue != newValue else {
                    return
                }
                filters.gradeMin = nil
                filters.gradeMax = nil
            }

            if let gradeSystem = filters.gradeSystem {
                Picker("Minimum grade", selection: $filters.gradeMin) {
                    Text("No minimum")
                        .tag(nil as String?)
                    ForEach(gradeSystem.values, id: \.self) { grade in
                        Text(grade)
                            .tag(grade as String?)
                    }
                }
                .onChange(of: filters.gradeMin) { _, newValue in
                    keepGradeRangeValid(changedMinimum: newValue)
                }

                Picker("Maximum grade", selection: $filters.gradeMax) {
                    Text("No maximum")
                        .tag(nil as String?)
                    ForEach(gradeSystem.values, id: \.self) { grade in
                        Text(grade)
                            .tag(grade as String?)
                    }
                }
                .onChange(of: filters.gradeMax) { _, newValue in
                    keepGradeRangeValid(changedMaximum: newValue)
                }
            }
        }
    }

    private var styleSection: some View {
        Section("Climbing style") {
            ForEach(ClimbingRoute.Style.allCases, id: \.self) { style in
                Toggle(
                    style.displayName,
                    isOn: Binding(
                        get: { filters.styles.contains(style) },
                        set: { isSelected in
                            if isSelected {
                                filters.styles.insert(style)
                            } else {
                                filters.styles.remove(style)
                            }
                        }
                    )
                )
            }
        }
    }

    private var lengthSection: some View {
        Section("Route length") {
            Toggle("Limit length", isOn: $usesLengthRange)

            if usesLengthRange {
                Stepper("Minimum: \(minimumLength) m", value: $minimumLength, in: 1...100)
                    .onChange(of: minimumLength) { _, newValue in
                        maximumLength = max(maximumLength, newValue)
                    }
                Stepper("Maximum: \(maximumLength) m", value: $maximumLength, in: 1...100)
                    .onChange(of: maximumLength) { _, newValue in
                        minimumLength = min(minimumLength, newValue)
                    }
            }
        }
    }

    private var pitchSection: some View {
        Section("Pitches") {
            Toggle("Limit pitches", isOn: $usesPitchRange)

            if usesPitchRange {
                Stepper("Minimum: \(minimumPitches)", value: $minimumPitches, in: 1...50)
                    .onChange(of: minimumPitches) { _, newValue in
                        maximumPitches = max(maximumPitches, newValue)
                    }
                Stepper("Maximum: \(maximumPitches)", value: $maximumPitches, in: 1...50)
                    .onChange(of: maximumPitches) { _, newValue in
                        minimumPitches = min(minimumPitches, newValue)
                    }
            }
        }
    }

    private func keepGradeRangeValid(changedMinimum: String?) {
        guard
            let gradeSystem = filters.gradeSystem,
            let changedMinimum,
            let maximum = filters.gradeMax,
            let minimumIndex = gradeSystem.values.firstIndex(of: changedMinimum),
            let maximumIndex = gradeSystem.values.firstIndex(of: maximum),
            minimumIndex > maximumIndex
        else {
            return
        }

        filters.gradeMax = changedMinimum
    }

    private func keepGradeRangeValid(changedMaximum: String?) {
        guard
            let gradeSystem = filters.gradeSystem,
            let changedMaximum,
            let minimum = filters.gradeMin,
            let maximumIndex = gradeSystem.values.firstIndex(of: changedMaximum),
            let minimumIndex = gradeSystem.values.firstIndex(of: minimum),
            maximumIndex < minimumIndex
        else {
            return
        }

        filters.gradeMin = changedMaximum
    }

    private func applyFilters() {
        filters.lengthMin = usesLengthRange ? minimumLength : nil
        filters.lengthMax = usesLengthRange ? maximumLength : nil
        filters.pitchesMin = usesPitchRange ? minimumPitches : nil
        filters.pitchesMax = usesPitchRange ? maximumPitches : nil
        onApply(filters)
        dismiss()
    }

    private func clearFilters() {
        filters = RouteFilters()
        usesLengthRange = false
        minimumLength = 1
        maximumLength = 50
        usesPitchRange = false
        minimumPitches = 1
        maximumPitches = 10
    }
}
