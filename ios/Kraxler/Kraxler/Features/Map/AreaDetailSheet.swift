import SwiftUI

struct AreaDetailSheet: View {
    private enum RouteState {
        case loading
        case loaded([ClimbingRoute])
        case failed(String)
    }

    let area: ClimbingArea
    let apiClient: APIClient

    @Environment(\.dismiss) private var dismiss
    @State private var routeState: RouteState = .loading

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
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: area.id) {
            await loadRoutes()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch routeState {
        case .loading:
            ProgressView("Loading routes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let routes) where routes.isEmpty:
            ContentUnavailableView(
                "No routes yet",
                systemImage: "figure.climbing",
                description: Text("This area does not have any routes in Kraxler yet.")
            )

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
            let routes = try await apiClient.routes(for: area.id)
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
                Text(route.styles.map(\.rawValue).map(\.capitalized).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
