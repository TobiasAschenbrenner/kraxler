import SwiftUI
import UIKit

struct AuthenticationScreen: View {
    fileprivate enum Mode: String, Hashable {
        case signIn = "Sign In"
        case createAccount = "Create Account"

    }

    @Environment(AuthSession.self) private var authSession
    @State private var errorMessage: String?
    @State private var isSigningInWithApple = false
    @State private var isSigningInWithGoogle = false

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
                Spacer(minLength: 116)

                brand

                Spacer(minLength: 88)

                VStack(spacing: 12) {
                    NavigationLink(value: Mode.createAccount) {
                        Text("Create Account")
                    }
                    .buttonStyle(KraxlerPrimaryButtonStyle(prominent: true))
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
                        systemImage: "apple.logo",
                        isLoading: isSigningInWithApple,
                        isDisabled: isSigningInWithApple || isSigningInWithGoogle
                    ) {
                        Task { await signInWithApple() }
                    }
                    .accessibilityIdentifier("authentication-apple")

                    SocialAuthenticationButton(
                        title: "Continue with Google",
                        systemImage: "g.circle.fill",
                        assetName: "GoogleMark",
                        isLoading: isSigningInWithGoogle,
                        isDisabled: isSigningInWithApple || isSigningInWithGoogle
                    ) {
                        Task { await signInWithGoogle() }
                    }
                    .accessibilityIdentifier("authentication-google")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("authentication-social-error")
                    }
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

    private func signInWithApple() async {
        guard let presentationAnchor = UIApplication.shared.kraxlerKeyWindow else {
            errorMessage = "Couldn’t open Apple sign-in."
            return
        }

        isSigningInWithApple = true
        errorMessage = nil
        defer { isSigningInWithApple = false }

        do {
            try await authSession.signInWithApple(presentationAnchor: presentationAnchor)
        } catch AuthenticationClientError.cancelled {
            return
        } catch {
            errorMessage = "Couldn’t sign in with Apple."
        }
    }

    private func signInWithGoogle() async {
        guard let presentingViewController = UIApplication.shared.kraxlerTopViewController else {
            errorMessage = "Couldn’t open Google sign-in."
            return
        }

        isSigningInWithGoogle = true
        errorMessage = nil
        defer { isSigningInWithGoogle = false }

        do {
            try await authSession.signInWithGoogle(
                presentingViewController: presentingViewController
            )
        } catch AuthenticationClientError.cancelled {
            return
        } catch {
            errorMessage = "Couldn’t sign in with Google."
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
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            KraxlerScreenBackground(showsTopography: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 24) {
                        if mode == .createAccount {
                            KraxlerBrandMark(size: 62)
                        }
                        Text(mode.rawValue)
                            .font(.largeTitle.bold())
                            .accessibilityIdentifier("authentication-form-title")
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
                            Group {
                                if isPasswordVisible {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    guard canSubmit, !isSubmitting else { return }
                                    Task { await submit() }
                                }
                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            }
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                            .frame(minWidth: 28, minHeight: 44)
                        }
                        .textContentType(mode == .signIn ? .password : .newPassword)
                        .accessibilityIdentifier("authentication-password")
                    }

                    if mode == .createAccount {
                        Label("Use at least \(AccountPasswordPolicy.minimumLength) characters", systemImage: "checkmark.shield")
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
                                Text("Continue")
                            }
                        }
                        .frame(height: 22)
                    }
                    .buttonStyle(KraxlerPrimaryButtonStyle(prominent: true))
                    .disabled(!canSubmit || isSubmitting)
                    .accessibilityIdentifier("authentication-submit")
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.top, 58)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("")
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
        email.contains("@") && (mode == .createAccount
            ? AccountPasswordPolicy.accepts(password)
            : !password.isEmpty)
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
    var assetName: String? = nil
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                } else {
                    if let assetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 22))
                    }
                }

                Text(title)
            }
        }
        .buttonStyle(KraxlerPrimaryButtonStyle())
        .disabled(isDisabled)
    }
}

private extension UIApplication {
    var kraxlerKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    var kraxlerTopViewController: UIViewController? {
        let rootViewController = kraxlerKeyWindow?.rootViewController

        return topViewController(from: rootViewController)
    }

    func topViewController(from viewController: UIViewController?) -> UIViewController? {
        if let navigationController = viewController as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }

        if let tabBarController = viewController as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }

        if let presentedViewController = viewController?.presentedViewController {
            return topViewController(from: presentedViewController)
        }

        return viewController
    }
}

#Preview {
    NavigationStack {
        AuthenticationScreen()
    }
    .environment(AuthSession())
}
