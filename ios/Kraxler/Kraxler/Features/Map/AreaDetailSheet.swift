import SwiftUI

struct AreaDetailSheet: View {
    private enum SheetDestination: String, Identifiable {
        case filters

        var id: String { rawValue }
    }

    private enum RouteState {
        case loading
        case loaded([ClimbingRoute])
        case failed(String)
    }

    let area: ClimbingArea
    let apiClient: APIClient

    @Environment(\.dismiss) private var dismiss
    @State private var routeState: RouteState = .loading
    @State private var filters = RouteFilters()
    @State private var sheetDestination: SheetDestination?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(area.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button("Filter", systemImage: filterSymbolName) {
                            sheetDestination = .filters
                        }
                        .accessibilityIdentifier("route-filter-button")
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: RouteRequestKey(areaID: area.id, filters: filters)) {
            await loadRoutes()
        }
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case .filters:
                RouteFilterSheet(filters: filters) { filters = $0 }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch routeState {
        case .loading:
            ProgressView("Loading routes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let routes) where routes.isEmpty:
            if filters.isEmpty {
                ContentUnavailableView(
                    "No routes yet",
                    systemImage: "figure.climbing",
                    description: Text("This area does not have any routes in Kraxler yet.")
                )
            } else {
                ContentUnavailableView {
                    Label("No matching routes", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("Try changing or clearing the active filters.")
                } actions: {
                    Button("Clear filters") {
                        filters = RouteFilters()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

        case .loaded(let routes):
            List(routes) { route in
                NavigationLink {
                    RouteDetailScreen(routeID: route.id, apiClient: apiClient)
                } label: {
                    RouteRow(route: route)
                }
                .accessibilityIdentifier("route-link-\(route.id)")
            }
            .listStyle(.plain)

        case .failed(let message):
            ContentUnavailableView {
                Label("Routes unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    Task {
                        await loadRoutes()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func loadRoutes() async {
        routeState = .loading

        do {
            let routes = try await apiClient.routes(for: area.id, filters: filters)
            guard !Task.isCancelled else {
                return
            }
            routeState = .loaded(routes)
        } catch is CancellationError {
            return
        } catch {
            routeState = .failed("The routes for \(area.name) could not be loaded.")
        }
    }

    private var filterSymbolName: String {
        filters.isEmpty
            ? "line.3.horizontal.decrease.circle"
            : "line.3.horizontal.decrease.circle.fill"
    }
}

private struct RouteRequestKey: Hashable {
    let areaID: String
    let filters: RouteFilters
}

private struct RouteRow: View {
    let route: ClimbingRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(route.name)
                    .font(.headline)

                Spacer()

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
