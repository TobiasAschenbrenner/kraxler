import SwiftUI

struct OfflineDownloadControl: View {
    let area: ClimbingArea
    let offlineDownloadsStore: OfflineDownloadsStore?

    var body: some View {
        if let offlineDownloadsStore {
            let operation = offlineDownloadsStore.operation(for: area.id)

            if operation.isInProgress {
                ProgressView(
                    value: offlineDownloadsStore.downloadProgress(for: area.id) ?? 0,
                    total: 1
                )
                .frame(width: 46, height: 46)
                .accessibilityLabel(
                    operation == .removing ? "Removing downloaded area" : "Downloading area"
                )
                .accessibilityIdentifier("offline-download-progress")
            } else if offlineDownloadsStore.hasAnyDownload(areaID: area.id) {
                Menu {
                    Button(
                        offlineDownloadsStore.hasIncompleteDownload(areaID: area.id)
                            ? "Complete download" : "Update download",
                        systemImage: "arrow.clockwise"
                    ) {
                        Task { await offlineDownloadsStore.download(area) }
                    }
                    Button("Remove download", systemImage: "trash", role: .destructive) {
                        Task { await offlineDownloadsStore.remove(areaID: area.id) }
                    }
                } label: {
                    Image(
                        systemName: offlineDownloadsStore.isAvailableOffline(areaID: area.id)
                            ? "arrow.down.circle.fill" : "exclamationmark.arrow.circlepath")
                }
                .buttonStyle(KraxlerIconButtonStyle(foregroundStyle: KraxlerDesign.accent))
                .accessibilityLabel("Offline options")
                .accessibilityIdentifier("offline-download-menu")
            } else {
                Button {
                    Task { await offlineDownloadsStore.download(area) }
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(KraxlerIconButtonStyle(foregroundStyle: KraxlerDesign.accent))
                .accessibilityLabel("Download area")
                .accessibilityIdentifier("offline-download-button")
            }
        }

    }
}

struct OfflineDownloadStatus: View {
    let areaID: String
    let offlineDownloadsStore: OfflineDownloadsStore?

    var body: some View {
        if let offlineDownloadsStore {
            switch offlineDownloadsStore.operation(for: areaID) {
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("offline-download-error")
            case .downloading:
                let progress = offlineDownloadsStore.downloadProgress(for: areaID) ?? 0
                HStack(spacing: 10) {
                    ProgressView(value: progress, total: 1).frame(width: 72)
                    Text(progress.formatted(.percent.precision(.fractionLength(0))))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("offline-download-status")
            case .removing:
                Label("Removing download…", systemImage: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("offline-download-status")
            case .idle:
                if offlineDownloadsStore.isAvailableOffline(areaID: areaID) {
                    Label("Available offline", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("offline-download-status")
                } else if offlineDownloadsStore.hasIncompleteDownload(areaID: areaID) {
                    Label("Download incomplete", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("offline-download-incomplete")
                }
            }
        }

    }
}
