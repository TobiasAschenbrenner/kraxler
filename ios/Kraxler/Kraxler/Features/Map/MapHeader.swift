import SwiftUI

struct MapHeader: View {
    let scale: CompactMapScale
    let locationIcon: String
    let locationLabel: String
    let locationIdentifier: String
    let onSearch: () -> Void
    let onLocate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                    Text("Kraxler")
                        .font(.system(.title, design: .rounded, weight: .bold))

                    KraxlerBrandMark(size: 38)
                }

                CompactMapScaleView(scale: scale)
            }
            .padding(.top, 8)

            Spacer()

            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    Button {
                        onSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(KraxlerIconButtonStyle())
                    .accessibilityLabel("Search climbing areas and routes")
                    .accessibilityIdentifier("map-search-button")

                    locationControl
                }
            }
        }
        .padding(.horizontal, KraxlerDesign.pagePadding)
        .padding(.top, 8)

    }

    private var locationControl: some View {
        Button {
            onLocate()
        } label: {
            Image(systemName: locationIcon)
        }
        .buttonStyle(KraxlerIconButtonStyle(foregroundStyle: KraxlerDesign.accent))
        .accessibilityLabel(locationLabel)
        .accessibilityIdentifier(locationIdentifier)
    }
}
