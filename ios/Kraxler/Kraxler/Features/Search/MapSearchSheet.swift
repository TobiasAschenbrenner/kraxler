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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var query = ""
    @State private var searchState: SearchState = .idle
    @State private var isExpanded = false
    @GestureState private var dragTranslation: CGFloat = 0
    @FocusState private var isSearchFocused: Bool

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
                        .fill(.clear)
                        .glassEffect(.regular, in: UnevenRoundedRectangle(
                            topLeadingRadius: 32, topTrailingRadius: 32
                        ))
                        .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("map-search-panel")
                .animation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0), value: isExpanded)
            }
        }
        .presentationBackground(.clear)
        .tint(KraxlerDesign.accent)
        .accessibilityAction(.escape) { dismiss() }
        .onChange(of: isSearchFocused) { _, isFocused in
            if isFocused { isExpanded = true }
        }
        .task(id: query) {
            await search()
        }
    }

    private var navigationContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeader
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .containerBackground(.clear, for: .navigation)
    }

    private var searchHeader: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .accessibilityHidden(true)
                    TextField("Area or route name", text: $query)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($isSearchFocused)
                        .onSubmit { isSearchFocused = false }
                        .accessibilityLabel("Search areas and routes")
                        .accessibilityIdentifier("map-search-field")
                }
                .padding(.horizontal, 16)
                .frame(minHeight: KraxlerDesign.controlSize)
                .contentShape(Capsule())
                .onTapGesture { isSearchFocused = true }
                .glassEffect(.regular.interactive(), in: .capsule)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(KraxlerIconButtonStyle(foregroundStyle: KraxlerDesign.accent))
                .accessibilityLabel("Close search")
                .accessibilityIdentifier("map-search-close")
            }
        }
        .padding(.horizontal, KraxlerDesign.pagePadding)
        .padding(.bottom, 12)
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
                            if isExpanded {
                                isSearchFocused = false
                                isExpanded = false
                            } else {
                                dismiss()
                            }
                        }
                    }
            )
            .accessibilityLabel("Sheet Grabber")
            .accessibilityAddTraits(.isButton)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    isExpanded = true
                case .decrement:
                    if isExpanded {
                        isSearchFocused = false
                        isExpanded = false
                    } else {
                        dismiss()
                    }
                @unknown default:
                    break
                }
            }
    }

    private func panelHeight(in availableHeight: CGFloat) -> CGFloat {
        let restingHeight = isExpanded ? availableHeight : availableHeight * 0.56
        return min(availableHeight, max(200, restingHeight - dragTranslation))
    }

    @ViewBuilder
    private var content: some View {
        switch searchState {
        case .idle:
            Color.clear

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
                    .listRowBackground(Color.primary.opacity(0.05))
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
                                .toolbar(.visible, for: .navigationBar)
                            } label: {
                                SearchRouteRow(route: route)
                            }
                            .accessibilityIdentifier("search-route-\(route.id)")
                        }
                    }
                    .listRowBackground(Color.primary.opacity(0.05))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

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
