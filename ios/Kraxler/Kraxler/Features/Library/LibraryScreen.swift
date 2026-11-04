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
            librarySummary

            routeList
        }
        .background(Color(.systemGroupedBackground))
    }

    private var librarySummary: some View {
        HStack(spacing: 12) {
            librarySectionButton(
                .saved,
                systemImage: "bookmark.fill",
                color: KraxlerDesign.accent
            )

            librarySectionButton(
                .ticked,
                systemImage: "checkmark.circle.fill",
                color: KraxlerDesign.success
            )
        }
        .padding(.horizontal, KraxlerDesign.pagePadding)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private func librarySectionButton(
        _ section: LibrarySection,
        systemImage: String,
        color: Color
    ) -> some View {
        let isSelected = selectedSection == section

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.rawValue)
                        .font(.subheadline.weight(.semibold))
                    Text(routeCount(for: section).formatted())
                        .font(.title2.bold().monospacedDigit())
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? color.gradient : Color(.secondarySystemGroupedBackground).gradient,
                in: RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(section.rawValue), \(routeCount(for: section)) routes")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("library-\(section.rawValue.lowercased())-section")
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
