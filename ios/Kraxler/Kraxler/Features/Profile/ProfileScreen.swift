import SwiftUI

struct ProfileScreen: View {
    let offlineDownloadsStore: OfflineDownloadsStore

    @Environment(AuthSession.self) private var authSession
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @State private var signOutErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                accountSection
                downloadsSection
                appearanceSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(KraxlerScreenBackground())
            .navigationTitle("Profile")
            .tint(KraxlerDesign.accent)
            .alert(
                "Sign out failed",
                isPresented: Binding(
                    get: { signOutErrorMessage != nil },
                    set: { if !$0 { signOutErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(signOutErrorMessage ?? "Please try again.")
            }
        }
        .accessibilityIdentifier("profile-screen")
    }

    private var identitySection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemBackground))

                    KraxlerBrandMark(size: 34)
                }
                .frame(width: 58, height: 58)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Climber")
                        .font(.title3.bold())

                    Text(authSession.account?.email ?? "Not available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("profile-email")
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color(.secondarySystemGroupedBackground))
    }

    private var downloadsSection: some View {
        Section("Offline") {
            NavigationLink {
                DownloadedAreasScreen(
                    offlineDownloadsStore: offlineDownloadsStore
                )
            } label: {
                HStack {
                    KraxlerSettingsLabel(
                        title: "Downloaded areas",
                        systemImage: "arrow.down.circle.fill"
                    )

                    Spacer()

                    Text(offlineDownloadsStore.downloadedManifests.count.formatted())
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("profile-downloads")
        }
    }

    private var accountSection: some View {
        Section("Account") {
            Button(role: .destructive) {
                do {
                    try authSession.signOut()
                } catch {
                    signOutErrorMessage = error.localizedDescription
                }
            } label: {
                KraxlerSettingsLabel(
                    title: "Sign out",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    color: .red
                )
            }
            .accessibilityIdentifier("profile-sign-out")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            KraxlerSettingsLabel(
                title: "Color scheme",
                systemImage: "circle.lefthalf.filled"
            )

            Picker("Appearance", selection: $appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.displayName).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("appearance-picker")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent {
                Text(versionText)
            } label: {
                KraxlerSettingsLabel(
                    title: "Version",
                    systemImage: "info.circle.fill"
                )
            }
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String

        return switch (version, build) {
        case let (.some(version), .some(build)):
            "\(version) (\(build))"
        case let (.some(version), .none):
            version
        case let (.none, .some(build)):
            build
        case (.none, .none):
            "Unknown"
        }
    }
}
