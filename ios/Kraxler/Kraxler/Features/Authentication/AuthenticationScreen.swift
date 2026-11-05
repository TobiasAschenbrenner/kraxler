import SwiftUI

struct AuthenticationScreen: View {
    fileprivate enum Mode: String, Hashable {
        case signIn = "Sign In"
        case createAccount = "Create Account"

        var prompt: String {
            switch self {
            case .signIn:
                "Welcome back"
            case .createAccount:
                "Create your account"
            }
        }
    }

    @Environment(AuthSession.self) private var authSession

    var body: some View {
        ZStack {
            KraxlerScreenBackground(showsTopography: true)

            if authSession.configurationState == .notConfigured {
                ContentUnavailableView {
                    Label("Account setup pending", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("Firebase still needs to be connected before accounts can be used.")
                }
            } else {
                landingContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("authentication-screen")
    }

    private var landingContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 126)

                brand

                Spacer(minLength: 88)

                VStack(spacing: 12) {
                    NavigationLink(value: Mode.createAccount) {
                        Text("Create Account")
                    }
                    .buttonStyle(KraxlerPrimaryButtonStyle())
                    .accessibilityIdentifier("authentication-create-account")

                    NavigationLink(value: Mode.signIn) {
                        Text("Sign In")
                    }
                    .buttonStyle(KraxlerPrimaryButtonStyle())
                    .accessibilityIdentifier("authentication-sign-in")

                    divider
                        .padding(.vertical, 12)

                    SocialAuthenticationButton(
                        title: "Continue with Apple",
                        systemImage: "apple.logo"
                    )
                    .accessibilityIdentifier("authentication-apple")

                    SocialAuthenticationButton(
                        title: "Continue with Google",
                        systemImage: "g.circle.fill"
                    )
                    .accessibilityIdentifier("authentication-google")
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationDestination(for: Mode.self) { mode in
            CredentialsScreen(mode: mode)
        }
    }

    private var brand: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("Kraxler")
                .font(.system(size: 48, weight: .bold, design: .rounded))

            KraxlerBrandMark(size: 58)
        }
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(.secondary.opacity(0.42))
                .frame(height: 0.5)

            Text("or")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(.secondary.opacity(0.42))
                .frame(height: 0.5)
        }
    }
}

private struct CredentialsScreen: View {
    let mode: AuthenticationScreen.Mode

    @Environment(AuthSession.self) private var authSession
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            KraxlerScreenBackground(showsTopography: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(mode.prompt)
                            .font(.largeTitle.bold())

                        Text(mode == .signIn
                            ? "Sign in to continue to Kraxler."
                            : "Save climbs, track ticks, and take areas offline.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        authenticationField(systemImage: "envelope") {
                            TextField("Email", text: $email)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        }
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("authentication-email")

                        authenticationField(systemImage: "lock") {
                            SecureField("Password", text: $password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    guard canSubmit, !isSubmitting else { return }
                                    Task { await submit() }
                                }
                        }
                        .textContentType(mode == .signIn ? .password : .newPassword)
                        .accessibilityIdentifier("authentication-password")
                    }

                    if mode == .createAccount {
                        Label("Use at least six characters", systemImage: "checkmark.shield")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("authentication-error")
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Group {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text(mode.rawValue)
                            }
                        }
                        .frame(height: 22)
                    }
                    .buttonStyle(KraxlerPrimaryButtonStyle())
                    .disabled(!canSubmit || isSubmitting)
                    .accessibilityIdentifier("authentication-submit")
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.top, 36)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func authenticationField<FieldContent: View>(
        systemImage: String,
        @ViewBuilder content: () -> FieldContent
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            content()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(
            Color(.secondarySystemBackground).opacity(0.94),
            in: RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil

        defer { isSubmitting = false }

        do {
            switch mode {
            case .signIn:
                try await authSession.signIn(email: email, password: password)
            case .createAccount:
                try await authSession.createAccount(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SocialAuthenticationButton: View {
    let title: String
    let systemImage: String

    @State private var showsComingSoon = false

    var body: some View {
        Button {
            showsComingSoon = true
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
        }
        .buttonStyle(.plain)
        .background(
            Color(.secondarySystemBackground).opacity(0.88),
            in: RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        }
        .alert("Coming soon", isPresented: $showsComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This sign-in option will be connected in a later milestone.")
        }
    }
}

#Preview {
    NavigationStack {
        AuthenticationScreen()
    }
    .environment(AuthSession())
}
