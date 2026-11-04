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
            Picker("Library section", selection: $selectedSection) {
                ForEach(LibrarySection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityIdentifier("library-section-picker")

            routeList
        }
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
            List(displayedRoutes) { personalRoute in
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
                        statusColor: selectedSection == .saved ? .orange : .green
                    )
                }
                .accessibilityIdentifier("library-route-\(personalRoute.routeId)")
            }
            .listStyle(.plain)
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

    private var emptyDescription: String {
        switch selectedSection {
        case .saved:
            "Save routes you want to find quickly or climb later."
        case .ticked:
            "Mark a route as ticked after you complete it."
        }
    }

}
