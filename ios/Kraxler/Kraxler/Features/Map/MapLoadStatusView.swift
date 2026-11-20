import SwiftUI

struct MapLoadStatusView: View {
    let status: MapScreenModel.LoadStatus
    let onRetry: () -> Void

    var body: some View {
        switch status {
        case .idle:
            EmptyView()

        case .loaded:
            EmptyView()

        case .loading:
            statusPill {
                ProgressView()
                Text("Loading areas")
            }

        case .failed(let message):
            statusCard {
                VStack(spacing: 10) {
                    Label("Areas unavailable", systemImage: "wifi.exclamationmark")
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)

                    Button("Try again", action: onRetry)
                        .buttonStyle(.borderedProminent)
                }
            }
        }

    }

    private func statusCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)
            .padding(.top, 156)
    }

    private func statusPill<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            content()
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 13)
        .frame(minHeight: 38)
        .kraxlerGlassSurface(cornerRadius: 19)
        .padding(.top, 156)
    }
}
