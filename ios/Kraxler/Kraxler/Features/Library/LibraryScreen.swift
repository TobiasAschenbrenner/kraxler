import SwiftUI

struct LibraryScreen: View {
    private enum LibrarySection: String, CaseIterable, Identifiable {
        case saved = "Saved"
        case ticked = "Ticked"

        var id: String { rawValue }
    }

    let personalRoutesStore: PersonalRoutesStore
    let climbingRepository: ClimbingRepository

    @Environment(AuthSession.self) private var authSession
    @State private var selectedSection: LibrarySection = .saved

    var body: some View {
        NavigationStack {
            libraryContent
                .navigationTitle("Library")
        }
        .task(id: authSession.account?.id) {
            guard authSession.isAuthenticated else {
                personalRoutesStore.reset()
                return
            }

            await personalRoutesStore.load(force: true)
        }
    }

    private var libraryContent: some View {
        VStack(spacing: 0) {
            sectionPicker

            routeList
        }
        .background(KraxlerScreenBackground())
    }

    private var sectionPicker: some View {
        Picker("Library section", selection: $selectedSection) {
            ForEach(LibrarySection.allCases) { section in
                Text("\(section.rawValue)  \(routeCount(for: section))")
                    .tag(section)
                    .accessibilityIdentifier(
                        "library-\(section.rawValue.lowercased())-section"
                    )
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, KraxlerDesign.pagePadding)
        .padding(.vertical, 12)
        .tint(.primary.opacity(0.78))
        .accessibilityIdentifier("library-section-picker")
    }

    @ViewBuilder
    private var routeList: some View {
        switch personalRoutesStore.loadState {
        case .idle, .loading:
            ProgressView("Loading your routes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded where displayedRoutes.isEmpty:
            ContentUnavailableView(
                selectedSection == .saved ? "No saved routes" : "No ticked routes",
                systemImage: selectedSection == .saved ? "bookmark" : "checkmark.circle",
                description: Text(emptyDescription)
            )

        case .loaded:
            List {
                ForEach(groupedRoutes, id: \.areaID) { group in
                    Section(areaName(from: group.areaID)) {
                        ForEach(group.routes) { personalRoute in
                            NavigationLink {
                                RouteDetailScreen(
                                    routeID: personalRoute.routeId,
                                    climbingRepository: climbingRepository,
                                    initialRoute: personalRoute.route,
                                    personalRoutesStore: personalRoutesStore
                                )
                            } label: {
                                RouteSummaryRow(
                                    route: personalRoute.route,
                                    statusSymbol: selectedSection == .saved
                                        ? "bookmark.fill"
                                        : "checkmark.circle.fill",
                                    statusColor: selectedSection == .saved
                                        ? KraxlerDesign.accent
                                        : KraxlerDesign.success
                                )
                            }
                            .accessibilityIdentifier(
                                "library-route-\(personalRoute.routeId)"
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable {
                await personalRoutesStore.load(force: true)
            }

        case .failed(let message):
            ContentUnavailableView {
                Label("Library unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    Task {
                        await personalRoutesStore.load(force: true)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var displayedRoutes: [PersonalRoute] {
        personalRoutesStore.routes.filter { personalRoute in
            switch selectedSection {
            case .saved:
                personalRoute.isSaved
            case .ticked:
                personalRoute.isTicked
            }
        }
    }

    private var groupedRoutes: [(areaID: String, routes: [PersonalRoute])] {
        Dictionary(grouping: displayedRoutes, by: { $0.route.areaId })
            .map { areaID, routes in
                (areaID, routes.sorted { $0.route.name < $1.route.name })
            }
            .sorted { areaName(from: $0.areaID) < areaName(from: $1.areaID) }
    }

    private func areaName(from areaID: String) -> String {
        areaID
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func routeCount(for section: LibrarySection) -> Int {
        personalRoutesStore.routes.count { personalRoute in
            switch section {
            case .saved:
                personalRoute.isSaved
            case .ticked:
                personalRoute.isTicked
            }
        }
    }

    private var emptyDescription: String {
        switch selectedSection {
        case .saved:
            "Save routes you want to find quickly or climb later."
        case .ticked:
            "Mark a route as ticked after you complete it."
        }
    }
}
