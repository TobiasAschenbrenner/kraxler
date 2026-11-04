import SwiftUI

struct ProfileScreen: View {
    @Environment(AuthSession.self) private var authSession
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @State private var signOutErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                appearanceSection
                aboutSection
            }
            .navigationTitle("Profile")
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

    private var accountSection: some View {
        Section("Account") {
            LabeledContent(
                "Email",
                value: authSession.account?.email ?? "Not available"
            )
            .accessibilityIdentifier("profile-email")

            Button(
                "Sign out",
                systemImage: "rectangle.portrait.and.arrow.right",
                role: .destructive
            ) {
                do {
                    try authSession.signOut()
                } catch {
                    signOutErrorMessage = error.localizedDescription
                }
            }
            .accessibilityIdentifier("profile-sign-out")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
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
            LabeledContent("Version", value: versionText)
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
