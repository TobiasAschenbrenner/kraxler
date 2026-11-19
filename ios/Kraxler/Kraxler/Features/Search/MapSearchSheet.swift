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
            Color(.systemBackground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                    .listRowBackground(KraxlerDesign.sectionBackground)
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
                    .listRowBackground(KraxlerDesign.sectionBackground)
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
            Text(area.name)
                .font(.headline)
        } icon: {
            Image(systemName: area.type.searchSymbolName)
                .foregroundStyle(KraxlerDesign.accent)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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

        }
        .padding(.vertical, 4)
    }
}

private extension ClimbingArea.AreaType {
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
