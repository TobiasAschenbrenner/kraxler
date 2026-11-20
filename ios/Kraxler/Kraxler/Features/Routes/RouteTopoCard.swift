import SwiftUI

struct RouteTopoCard: View {
    let topo: ClimbingRoute.Topo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: topo.imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("Topo showing route number \(topo.routeNumber)")
                case .failure:
                    ContentUnavailableView(
                        "Topo unavailable",
                        systemImage: "photo",
                        description: Text("Connect to the internet to load this image.")
                    )
                    .frame(minHeight: 160)
                default:
                    ProgressView("Loading topo…")
                        .frame(maxWidth: .infinity, minHeight: 160)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius))

            Label("Route number \(topo.routeNumber)", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("route-topo-\(topo.id)")
    }
}
