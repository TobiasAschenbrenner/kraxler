import SwiftUI

struct ProfileScreen: View {
    private enum Destination: String, Identifiable {
        case editProfile
        var id: String { rawValue }
    }

    let offlineDownloadsStore: OfflineDownloadsStore
    var apiClient: APIClient = APIClient()

    @Environment(AuthSession.self) private var authSession
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @State private var signOutErrorMessage: String?
    @State private var profile: UserProfile?
    @State private var profileLoadFailed = false
    @State private var destination: Destination?

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
        .task(id: authSession.account?.id) {
            profile = nil
            await loadProfile()
        }
        .sheet(item: $destination) { _ in
            EditProfileScreen(
                profile: profile,
                account: authSession.account,
                apiClient: apiClient
            ) { profile = $0 }
        }
        .accessibilityIdentifier("profile-screen")
    }

    private var identitySection: some View {
        Section {
            HStack(spacing: 16) {
                ProfileAvatar(
                    data: profile?.avatarData,
                    photoURL: profile?.photoURL(providerURL: authSession.account?.photoURL)
                        ?? (profile == nil ? authSession.account?.photoURL : nil),
                    size: 58
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile?.displayName ?? authSession.account?.displayName ?? "Climber")
                        .font(.title3.bold())
                        .accessibilityIdentifier("profile-name")

                    Text(authSession.account?.email ?? "Not available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("profile-email")
                }

                Spacer(minLength: 0)

                Button {
                    destination = .editProfile
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Edit profile")
                .accessibilityIdentifier("profile-edit")
                .disabled(profile == nil)
            }
            .padding(.vertical, 8)

            if profileLoadFailed {
                Button("Retry loading profile", systemImage: "arrow.clockwise") {
                    Task { await loadProfile() }
                }
                .font(.caption)
            }
        }
        .listRowBackground(KraxlerDesign.sectionBackground)
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
        .listRowBackground(KraxlerDesign.sectionBackground)
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
        .listRowBackground(KraxlerDesign.sectionBackground)
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            VStack(alignment: .leading, spacing: 12) {
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
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("appearance-picker")
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(KraxlerDesign.sectionBackground)
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
        .listRowBackground(KraxlerDesign.sectionBackground)
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

    private func loadProfile() async {
        let accountID = authSession.account?.id
        guard accountID != nil else { return }
        do {
            let loaded = try await apiClient.userProfile()
            guard !Task.isCancelled, accountID == authSession.account?.id else { return }
            profile = loaded
            profileLoadFailed = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            profileLoadFailed = true
        }
    }
}
