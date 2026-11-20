import SwiftUI

struct PersonalRouteActions: View {
    let state: PersonalRouteState
    let isUpdating: Bool
    let errorMessage: String?
    let onSave: () async -> Void
    let onTick: () async -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                routeButton(
                    title: state.isSaved ? "Saved" : "Save",
                    symbol: state.isSaved ? "bookmark.fill" : "bookmark",
                    isActive: state.isSaved, action: onSave
                )
                .accessibilityIdentifier("route-save-button")
                routeButton(
                    title: state.isTicked ? "Ticked" : "Tick",
                    symbol: state.isTicked ? "checkmark.circle.fill" : "checkmark.circle",
                    isActive: state.isTicked, action: onTick
                )
                .accessibilityIdentifier("route-tick-button")
            }
            if let errorMessage {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(KraxlerDesign.warning)
                    .accessibilityLabel(errorMessage)
                    .accessibilityIdentifier("personal-route-error")
            }
        }
    }

    private func routeButton(
        title: String, symbol: String, isActive: Bool, action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: symbol)
        }
        .buttonStyle(
            KraxlerIconButtonStyle(foregroundStyle: isActive ? KraxlerDesign.accent : .secondary)
        )
        .accessibilityLabel(title)
        .accessibilityValue(isActive ? "Selected" : "Not selected")
        .disabled(isUpdating)
    }
}
