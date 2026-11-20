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
        case notAvailableOffline
    }

    let area: ClimbingArea
    let climbingRepository: ClimbingRepository
    let personalRoutesStore: PersonalRoutesStore?
    let offlineDownloadsStore: OfflineDownloadsStore?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .headline) private var routesHeadingSize: CGFloat = 19
    @State private var routeState: RouteState = .loading
    @State private var filters = RouteFilters()
    @State private var sheetDestination: SheetDestination?
    @State private var isExpanded = false
    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    dragHandle
                    navigationContent
                }
                .frame(maxWidth: .infinity)
                .frame(height: panelHeight(in: geometry.size.height))
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32)
                        .fill(Color(.systemBackground))
                        .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("area-detail-panel")
                .animation(
                    reduceMotion ? nil : .spring(duration: 0.55, bounce: 0), value: isExpanded)
            }
        }
        .presentationBackground(.clear)
        .tint(KraxlerDesign.accent)
        .accessibilityAction(.escape) { dismiss() }
        .task(
            id: RouteRequestKey(
                areaID: area.id, filters: filters,
                connectionRevision: climbingRepository.connectionRevision)
        ) {
            await loadRoutes()
        }
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case .filters:
                RouteFilterSheet(filters: filters) { filters = $0 }
            }
        }
    }

    private var navigationContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                areaControlsHeader
                routesHeader
                routeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .containerBackground(.clear, for: .navigation)
    }

    private var areaControlsHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            GlassEffectContainer(spacing: 12) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(KraxlerIconButtonStyle(foregroundStyle: KraxlerDesign.accent))
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("area-detail-close")
                    Spacer()
                    OfflineDownloadControl(area: area, offlineDownloadsStore: offlineDownloadsStore)
                }
            }
            AreaSummaryHeader(area: area, routes: loadedRoutes)
        }
        .padding(.horizontal, KraxlerDesign.pagePadding)
        .padding(.bottom, 8)
    }

    private var routesHeader: some View {
        HStack {
            Text("Routes")
                .font(.system(size: routesHeadingSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("area-routes-heading")
            Spacer()
            Button {
                sheetDestination = .filters
            } label: {
                Image(systemName: filterSymbolName)
            }
            .buttonStyle(KraxlerIconButtonStyle(foregroundStyle: KraxlerDesign.accent))
            .accessibilityLabel("Filter")
            .accessibilityIdentifier("route-filter-button")
        }
        .padding(.horizontal, KraxlerDesign.pagePadding)
        .padding(.bottom, 16)
    }

    private var loadedRoutes: [ClimbingRoute]? {
        guard case .loaded(let routes, _) = routeState else {
            return nil
        }
        return routes
    }

    private var dragHandle: some View {
        Capsule()
            .fill(.secondary.opacity(0.45))
            .frame(width: 44, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($dragTranslation) { value, translation, _ in
                        translation = value.translation.height
                    }
                    .onEnded { value in
                        let travel = value.predictedEndTranslation.height
                        if travel < -60 {
                            isExpanded = true
                        } else if travel > 100 {
                            collapseOrDismiss()
                        }
                    }
            )
            .accessibilityLabel("Sheet Grabber")
            .accessibilityIdentifier("area-detail-grabber")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityAddTraits(.isButton)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    isExpanded = true
                case .decrement:
                    collapseOrDismiss()
                @unknown default:
                    break
                }
            }
    }

    private func panelHeight(in availableHeight: CGFloat) -> CGFloat {
        let restingHeight = isExpanded ? availableHeight : availableHeight * 0.56
        return min(availableHeight, max(200, restingHeight - dragTranslation))
    }

    private func collapseOrDismiss() {
        if isExpanded {
            isExpanded = false
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch routeState {
        case .loading:
            VStack(spacing: 24) {
                Spacer()
                ProgressView("Loading routes…")
                Spacer()
            }

        case .loaded(let routes, _) where routes.isEmpty && filters.isEmpty:
            VStack(spacing: 18) {
                ContentUnavailableView(
                    "No routes yet",
                    systemImage: "figure.climbing",
                    description: nil
                )
            }

        case .loaded(let routes, let source):
            List {
                OfflineDownloadStatus(areaID: area.id, offlineDownloadsStore: offlineDownloadsStore)

                if source == .offline {
                    Label("Showing downloaded routes", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("offline-routes-indicator")
                }

                if !filters.isEmpty {
                    Section { AppliedRouteFilters(filters: $filters) }
                        .listRowBackground(Color.clear)
                }

                if routes.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "No matching routes", systemImage: "line.3.horizontal.decrease.circle")
                    } actions: {
                        Button("Clear filters") { filters = RouteFilters() }
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(routes) { route in
                            NavigationLink {
                                RouteDetailScreen(
                                    routeID: route.id,
                                    climbingRepository: climbingRepository,
                                    initialRoute: route,
                                    areaName: area.name,
                                    climbingAreaID: area.type == .climbingArea ? area.id : nil,
                                    personalRoutesStore: personalRoutesStore
                                )
                                .toolbar(.visible, for: .navigationBar)
                            } label: {
                                RouteSummaryRow(route: route)
                            }
                            .accessibilityIdentifier("route-link-\(route.id)")
                        }
                    }
                    .listRowBackground(KraxlerDesign.sectionBackground)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 0, for: .scrollContent)

        case .notAvailableOffline:
            ContentUnavailableView("Not available offline", systemImage: "wifi.slash")

        case .failed(let message):
            VStack(spacing: 18) {
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

    private func loadRoutes() async {
        routeState = .loading
        do {
            let response = try await climbingRepository.routes(for: area.id, filters: filters)
            guard !Task.isCancelled else { return }
            routeState = .loaded(response.value, response.source)
        } catch is CancellationError {
            return
        } catch ClimbingRepositoryError.notAvailableOffline {
            guard !Task.isCancelled else { return }
            routeState = .notAvailableOffline
        } catch {
            guard !Task.isCancelled else { return }
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
    let connectionRevision: Int
}

extension ClimbingArea.AreaType {
    fileprivate var displayName: String {
        switch self {
        case .region: "Climbing region"
        case .climbingArea: "Climbing area"
        case .sector: "Climbing sector"
        }
    }
}
