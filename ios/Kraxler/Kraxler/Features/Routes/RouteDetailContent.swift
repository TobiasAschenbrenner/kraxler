import SwiftUI

struct RouteDetailContent<Actions: View>: View {
    let route: ClimbingRoute
    let source: ClimbingContentSource
    let localTopoURLs: [String: URL]
    let actions: Actions

    init(
        route: ClimbingRoute,
        source: ClimbingContentSource,
        localTopoURLs: [String: URL] = [:],
        @ViewBuilder actions: () -> Actions
    ) {
        self.route = route
        self.source = source
        self.localTopoURLs = localTopoURLs
        self.actions = actions()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                RouteMapPreview(route: route, source: source)
                routeHeader
                facts

                if let topos = route.topos, !topos.isEmpty {
                    section("Route topo") {
                        ForEach(topos) { topo in
                            RouteTopoCard(topo: topo, localImageURL: localTopoURLs[topo.id])
                        }
                    }
                }

                if !route.styles.isEmpty {
                    styles
                }

                if let description = route.description, !description.isEmpty {
                    section("Description") {
                        Text(description)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("route-detail-description")
                    }
                }
            }
            .padding(.horizontal, KraxlerDesign.pagePadding)
            .padding(.bottom, 32)
        }
        .background(KraxlerScreenBackground())
        .ignoresSafeArea(edges: .top)
        .accessibilityIdentifier("route-detail-screen")
    }

    private var routeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(route.name)
                .font(.largeTitle.bold())
                .accessibilityIdentifier("route-detail-name")

            HStack(spacing: 8) {
                Text(route.grade.value)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(KraxlerDesign.accent)
                    .accessibilityIdentifier("route-detail-grade")

                Text(route.discipline.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("route-detail-discipline")

                Spacer(minLength: 12)
                actions
            }
        }
    }

    private var facts: some View {
        HStack(spacing: 0) {
            fact(
                title: "Grade system",
                value: route.grade.system.displayName,
                systemImage: "chart.bar"
            )

            if let lengthMeters = route.lengthMeters {
                Divider().frame(height: 38)
                fact(
                    title: "Length",
                    value: "\(lengthMeters.formatted()) m",
                    systemImage: "ruler"
                )
            }

            if let pitches = route.pitches {
                Divider().frame(height: 38)
                fact(
                    title: "Pitches",
                    value: pitches.formatted(),
                    systemImage: "arrow.up.right"
                )
            }
        }
        .padding(.vertical, 14)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
        )
    }

    private var styles: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(route.styles, id: \.self) { style in
                    Text(style.displayName)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Color(.secondarySystemBackground),
                            in: Capsule()
                        )
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("route-detail-styles")
    }

    private func fact(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        VStack(spacing: 5) {
            Label(value, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KraxlerDesign.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}
