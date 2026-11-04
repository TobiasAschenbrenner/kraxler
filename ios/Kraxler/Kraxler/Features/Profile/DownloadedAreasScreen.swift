import SwiftUI

struct DownloadedAreasScreen: View {
    let offlineDownloadsStore: OfflineDownloadsStore

    var body: some View {
        Group {
            if offlineDownloadsStore.downloadedManifests.isEmpty {
                ContentUnavailableView(
                    "No downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Downloaded climbing areas appear here.")
                )
            } else {
                List(offlineDownloadsStore.downloadedManifests) { manifest in
                    downloadedAreaRow(manifest)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await offlineDownloadsStore.load()
        }
        .accessibilityIdentifier("downloaded-areas-screen")
    }

    private func downloadedAreaRow(
        _ manifest: OfflineAreaManifest
    ) -> some View {
        let operation = offlineDownloadsStore.operation(for: manifest.area.id)

        return HStack(spacing: 12) {
            Image(
                systemName: offlineDownloadsStore.isAvailableOffline(
                    areaID: manifest.area.id
                )
                    ? "arrow.down.circle.fill"
                    : "exclamationmark.arrow.circlepath"
            )
            .font(.title2)
            .foregroundStyle(
                offlineDownloadsStore.isAvailableOffline(areaID: manifest.area.id)
                    ? .orange
                    : .secondary
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(manifest.area.name)
                    .font(.headline)

                Text(downloadSummary(for: manifest))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if case .failed(let message) = operation {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            if operation.isInProgress {
                ProgressView()
                    .accessibilityLabel(
                        operation == .removing
                            ? "Removing \(manifest.area.name)"
                            : "Updating \(manifest.area.name)"
                    )
            } else {
                Menu {
                    Button("Update", systemImage: "arrow.clockwise") {
                        Task {
                            await offlineDownloadsStore.download(manifest.area)
                        }
                    }

                    Button(
                        "Remove",
                        systemImage: "trash",
                        role: .destructive
                    ) {
                        Task {
                            await offlineDownloadsStore.remove(
                                areaID: manifest.area.id
                            )
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .accessibilityLabel("Manage \(manifest.area.name)")
                .accessibilityIdentifier(
                    "download-actions-\(manifest.area.id)"
                )
            }
        }
        .accessibilityIdentifier("downloaded-area-\(manifest.area.id)")
    }

    private func downloadSummary(for manifest: OfflineAreaManifest) -> String {
        let routeSummary = "\(manifest.routeCount) "
            + (manifest.routeCount == 1 ? "route" : "routes")
        let updated = manifest.refreshedAt.formatted(
            date: .abbreviated,
            time: .omitted
        )
        return "\(routeSummary) · Updated \(updated)"
    }
}
