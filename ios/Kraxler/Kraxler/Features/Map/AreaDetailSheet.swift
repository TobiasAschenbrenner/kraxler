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
            routeContent
                .background(KraxlerScreenBackground())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
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
        .presentationBackground(.regularMaterial)
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
    private var routeContent: some View {
        switch routeState {
        case .loading:
            VStack(spacing: 24) {
                areaHeader(routes: nil)
                    .padding(.horizontal, KraxlerDesign.pagePadding)
                Spacer()
                ProgressView("Loading routes…")
                Spacer()
            }

        case .loaded(let routes, _) where routes.isEmpty && filters.isEmpty:
            VStack(spacing: 18) {
                areaHeader(routes: routes)
                    .padding(.horizontal, KraxlerDesign.pagePadding)
                ContentUnavailableView(
                    "No routes yet",
                    systemImage: "figure.climbing",
                    description: Text("This area does not have any routes in Kraxler yet.")
                )
            }

        case .loaded(let routes, let source):
            List {
                Section {
                    areaHeader(routes: routes)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 14, trailing: 20))
                        .listRowBackground(Color.clear)
                }

                offlineDownloadStatus

                if source == .offline {
                    Label("Showing downloaded routes", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("offline-routes-indicator")
                }

                if !filters.isEmpty {
                    Section { activeFilterChips }
                        .listRowBackground(Color.clear)
                }

                if routes.isEmpty {
                    ContentUnavailableView {
                        Label("No matching routes", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Try changing or clearing the active filters.")
                    } actions: {
                        Button("Clear filters") { filters = RouteFilters() }
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section("Routes") {
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
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

        case .failed(let message):
            VStack(spacing: 18) {
                areaHeader(routes: nil)
                    .padding(.horizontal, KraxlerDesign.pagePadding)
                ContentUnavailableView {
                    Label("Routes unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { Task { await loadRoutes() } }
                }
            }
        }
    }

    private func areaHeader(routes: [ClimbingRoute]?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(area.name)
                        .font(.largeTitle.bold())
                    Text(area.type.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                offlineDownloadControl
            }

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

    @ViewBuilder
    private var offlineDownloadControl: some View {
        if let offlineDownloadsStore {
            let operation = offlineDownloadsStore.operation(for: area.id)

            if operation.isInProgress {
                ProgressView(
                    value: offlineDownloadsStore.downloadProgress(for: area.id) ?? 0,
                    total: 1
                )
                .frame(width: 46, height: 46)
                .accessibilityLabel(operation == .removing ? "Removing downloaded area" : "Downloading area")
                .accessibilityIdentifier("offline-download-progress")
            } else if offlineDownloadsStore.hasAnyDownload(areaID: area.id) {
                Menu {
                    Button(
                        offlineDownloadsStore.hasIncompleteDownload(areaID: area.id)
                            ? "Complete download" : "Update download",
                        systemImage: "arrow.clockwise"
                    ) {
                        Task { await offlineDownloadsStore.download(area) }
                    }
                    Button("Remove download", systemImage: "trash", role: .destructive) {
                        Task { await offlineDownloadsStore.remove(areaID: area.id) }
                    }
                } label: {
                    Image(systemName: offlineDownloadsStore.isAvailableOffline(areaID: area.id)
                        ? "arrow.down.circle.fill" : "exclamationmark.arrow.circlepath")
                }
                .buttonStyle(KraxlerIconButtonStyle(foregroundStyle: KraxlerDesign.accent))
                .accessibilityLabel("Offline options")
                .accessibilityIdentifier("offline-download-menu")
            } else {
                Button {
                    Task { await offlineDownloadsStore.download(area) }
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(KraxlerIconButtonStyle(foregroundStyle: KraxlerDesign.accent))
                .accessibilityLabel("Download area")
                .accessibilityIdentifier("offline-download-button")
            }
        }
    }

    @ViewBuilder
    private var offlineDownloadStatus: some View {
        if let offlineDownloadsStore {
            switch offlineDownloadsStore.operation(for: area.id) {
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("offline-download-error")
            case .downloading:
                let progress = offlineDownloadsStore.downloadProgress(for: area.id) ?? 0
                HStack(spacing: 10) {
                    ProgressView(value: progress, total: 1).frame(width: 72)
                    Text(progress.formatted(.percent.precision(.fractionLength(0))))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("offline-download-status")
            case .removing:
                Label("Removing download…", systemImage: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("offline-download-status")
            case .idle:
                if offlineDownloadsStore.isAvailableOffline(areaID: area.id) {
                    Label("Available offline", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("offline-download-status")
                } else if offlineDownloadsStore.hasIncompleteDownload(areaID: area.id) {
                    Label("Download incomplete", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("offline-download-incomplete")
                }
            }
        }
    }

    private var activeFilterChips: some View {
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
                ForEach(filters.styles.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { style in
                    filterChip(style.displayName) { filters.styles.remove(style) }
                }
                if filters.lengthMin != nil || filters.lengthMax != nil {
                    filterChip("Length") {
                        filters.lengthMin = nil
                        filters.lengthMax = nil
                    }
                }
                if filters.pitchesMin != nil || filters.pitchesMax != nil {
                    filterChip("Pitches") {
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
        case let (.some(minimum), .some(maximum)): "\(minimum)–\(maximum)"
        case let (.some(minimum), .none): "\(minimum)+"
        case let (.none, .some(maximum)): "Up to \(maximum)"
        case (.none, .none): filters.gradeSystem?.displayName ?? "Grade"
        }
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

    private func loadRoutes() async {
        routeState = .loading
        do {
            let response = try await climbingRepository.routes(for: area.id, filters: filters)
            guard !Task.isCancelled else { return }
            routeState = .loaded(response.value, response.source)
        } catch is CancellationError {
            return
        } catch {
            routeState = .failed("The routes for \(area.name) could not be loaded.")
        }
    }

    private var filterSymbolName: String {
        filters.isEmpty ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill"
    }
}

private struct RouteRequestKey: Hashable {
    let areaID: String
    let filters: RouteFilters
}

private extension ClimbingArea.AreaType {
    var displayName: String {
        switch self {
        case .region: "Climbing region"
        case .climbingArea: "Climbing area"
        case .sector: "Climbing sector"
        }
    }
}
