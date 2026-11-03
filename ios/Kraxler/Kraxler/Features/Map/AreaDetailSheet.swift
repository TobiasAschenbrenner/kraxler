import SwiftUI

struct AreaDetailSheet: View {
    private enum SheetDestination: String, Identifiable {
        case filters

        var id: String { rawValue }
    }

    private enum RouteState {
        case loading
        case loaded([ClimbingRoute], ClimbingContentSource)
        case failed(String)
    }

    let area: ClimbingArea
    let climbingRepository: ClimbingRepository
    let personalRoutesStore: PersonalRoutesStore?
    let offlineDownloadsStore: OfflineDownloadsStore?

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

                    ToolbarItemGroup(placement: .primaryAction) {
                        offlineDownloadControl

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
    private var offlineDownloadControl: some View {
        if let offlineDownloadsStore {
            let operation = offlineDownloadsStore.operation(for: area.id)

            if operation.isInProgress {
                ProgressView()
                    .accessibilityLabel(
                        operation == .removing
                            ? "Removing downloaded area"
                            : "Downloading area"
                    )
                    .accessibilityIdentifier("offline-download-progress")
            } else if offlineDownloadsStore.manifest(for: area.id) != nil {
                Menu {
                    Button("Update download", systemImage: "arrow.clockwise") {
                        Task {
                            await offlineDownloadsStore.download(area)
                        }
                    }

                    Button(
                        "Remove download",
                        systemImage: "trash",
                        role: .destructive
                    ) {
                        offlineDownloadsStore.remove(areaID: area.id)
                    }
                } label: {
                    Label("Offline options", systemImage: "arrow.down.circle.fill")
                }
                .accessibilityIdentifier("offline-download-menu")
            } else {
                Button("Download area", systemImage: "arrow.down.circle") {
                    Task {
                        await offlineDownloadsStore.download(area)
                    }
                }
                .accessibilityIdentifier("offline-download-button")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            offlineDownloadStatus
            routeContent
        }
    }

    @ViewBuilder
    private var offlineDownloadStatus: some View {
        if let offlineDownloadsStore {
            switch offlineDownloadsStore.operation(for: area.id) {
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08))
                    .accessibilityIdentifier("offline-download-error")

            case .idle, .downloading, .removing:
                if let manifest = offlineDownloadsStore.manifest(for: area.id) {
                    Label {
                        Text(
                            "Available offline · \(manifest.routeCount) "
                                + "\(manifest.routeCount == 1 ? "route" : "routes") · "
                                + "Updated \(manifest.refreshedAt.formatted(date: .abbreviated, time: .shortened))"
                        )
                    } icon: {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.green.opacity(0.08))
                    .accessibilityIdentifier("offline-download-status")
                }
            }
        }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch routeState {
        case .loading:
            ProgressView("Loading routes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let routes, _) where routes.isEmpty:
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

        case .loaded(let routes, let source):
            List {
                if source == .offline {
                    Label("Showing downloaded routes", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("offline-routes-indicator")
                }

                ForEach(routes) { route in
                    NavigationLink {
                        RouteDetailScreen(
                            routeID: route.id,
                            climbingRepository: climbingRepository,
                            personalRoutesStore: personalRoutesStore
                        )
                    } label: {
                        RouteSummaryRow(route: route)
                    }
                    .accessibilityIdentifier("route-link-\(route.id)")
                }
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
            let response = try await climbingRepository.routes(
                for: area.id,
                filters: filters
            )
            guard !Task.isCancelled else {
                return
            }
            routeState = .loaded(response.value, response.source)
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
