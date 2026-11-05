import SwiftUI

struct MapSearchSheet: View {
    private enum SearchState {
        case idle
        case loading
        case loaded(SearchResults, ClimbingContentSource)
        case failed(String)
    }

    let climbingRepository: ClimbingRepository
    let personalRoutesStore: PersonalRoutesStore?
    let onSelectArea: (ClimbingArea) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var searchState: SearchState = .idle

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Area or route name"
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") {
                            dismiss()
                        }
                    }
                }
        }
        .tint(KraxlerDesign.accent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: query) {
            await search()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch searchState {
        case .idle:
            ContentUnavailableView(
                "Find your next climb",
                systemImage: "magnifyingglass",
                description: Text("Search globally by climbing area or route name.")
            )

        case .loading:
            ProgressView("Searching…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let results, _) where results.isEmpty:
            ContentUnavailableView.search(text: query)

        case .loaded(let results, let source):
            List {
                if source == .offline {
                    Label("Searching downloaded areas", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("offline-search-indicator")
                }

                if !results.areas.isEmpty {
                    Section("Areas") {
                        ForEach(results.areas) { area in
                            Button {
                                onSelectArea(area)
                                dismiss()
                            } label: {
                                SearchAreaRow(area: area)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("search-area-\(area.id)")
                        }
                    }
                }

                if !results.routes.isEmpty {
                    Section("Routes") {
                        ForEach(results.routes) { route in
                            NavigationLink {
                                RouteDetailScreen(
                                    routeID: route.id,
                                    climbingRepository: climbingRepository,
                                    initialRoute: route,
                                    personalRoutesStore: personalRoutesStore
                                )
                            } label: {
                                SearchRouteRow(route: route)
                            }
                            .accessibilityIdentifier("search-route-\(route.id)")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(KraxlerScreenBackground())

        case .failed(let message):
            ContentUnavailableView {
                Label("Search unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    Task {
                        await performSearch(for: query)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func search() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedQuery.count >= 2 else {
            searchState = .idle
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else {
                return
            }
            await performSearch(for: trimmedQuery)
        } catch is CancellationError {
            return
        } catch {
            searchState = .failed("Search could not be completed. Please try again.")
        }
    }

    private func performSearch(for query: String) async {
        searchState = .loading

        do {
            let response = try await climbingRepository.search(query)
            guard !Task.isCancelled else {
                return
            }
            searchState = .loaded(response.value, response.source)
        } catch is CancellationError {
            return
        } catch {
            searchState = .failed("Search could not be completed. Please try again.")
        }
    }
}

private struct SearchAreaRow: View {
    let area: ClimbingArea

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(area.name)
                    .font(.headline)
                Text(area.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: area.type.searchSymbolName)
                .foregroundStyle(KraxlerDesign.accent)
        }
        .padding(.vertical, 4)
    }
}

private struct SearchRouteRow: View {
    let route: ClimbingRoute

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(route.name)
                        .font(.headline)
                    Text(route.grade.value)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(KraxlerDesign.accent)
                }
                Text(route.discipline.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private extension ClimbingArea.AreaType {
    var displayName: String {
        switch self {
        case .region:
            "Region"
        case .climbingArea:
            "Climbing area"
        case .sector:
            "Sector"
        }
    }

    var searchSymbolName: String {
        switch self {
        case .region:
            "mountain.2.fill"
        case .climbingArea:
            "mappin.circle.fill"
        case .sector:
            "figure.climbing"
        }
    }
}
