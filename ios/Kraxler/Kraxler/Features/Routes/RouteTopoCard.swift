import SwiftUI

struct RouteTopoCard: View {
    let topo: ClimbingRoute.Topo
    var localImageURL: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let localImageURL {
                    LocalTopoImage(url: localImageURL, routeNumber: topo.routeNumber)
                } else {
                    remoteImage
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius))

            Label(
                "Route number \(topo.routeNumber)",
                systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("route-topo-\(topo.id)")
    }

    private var remoteImage: some View {
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
    }
}

private struct LocalTopoImage: View {
    let url: URL
    let routeNumber: String
    @State private var imageData: Data?
    @State private var failed = false

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Topo showing route number \(routeNumber)")
                    .accessibilityValue("Available offline")
                    .accessibilityIdentifier("offline-topo-image")
            } else if failed {
                ContentUnavailableView("Topo unavailable", systemImage: "photo")
                    .frame(minHeight: 160)
            } else {
                ProgressView("Loading topo…")
                    .frame(maxWidth: .infinity, minHeight: 160)
            }
        }
        .task(id: url) {
            imageData = nil
            failed = false
            do {
                let file = url
                let data = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: file, options: .mappedIfSafe)
                }.value
                guard !Task.isCancelled else { return }
                if UIImage(data: data) == nil { failed = true } else { imageData = data }
            } catch {
                if !Task.isCancelled { failed = true }
            }
        }
    }
}
