import SwiftUI

struct AuthenticationScreen: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign in"
        case createAccount = "Create account"

        var id: String { rawValue }
    }

    @Environment(AuthSession.self) private var authSession

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if authSession.configurationState == .notConfigured {
                ContentUnavailableView {
                    Label("Account setup pending", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("Firebase still needs to be connected before accounts can be used.")
                }
            } else {
                VStack(spacing: 0) {
                    header
                    form
                }
            }
        }
        .accessibilityIdentifier("authentication-screen")
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Kraxler")
                .font(.largeTitle.bold())
        }
        .padding(.top, 48)
        .padding(.bottom, 24)
    }

    private var form: some View {
        Form {
            Section {
                Picker("Account action", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("authentication-mode-picker")
            }

            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("authentication-email")

                SecureField("Password", text: $password)
                    .textContentType(mode == .signIn ? .password : .newPassword)
                    .accessibilityIdentifier("authentication-password")
            } footer: {
                if mode == .createAccount {
                    Text("Use at least six characters for your password.")
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("authentication-error")
                }
            }

            Section {
                Button {
                    Task {
                        await submit()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(mode.rawValue)
                        }
                        Spacer()
                    }
                }
                .disabled(!canSubmit || isSubmitting)
                .accessibilityIdentifier("authentication-submit")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil

        defer {
            isSubmitting = false
        }

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

#Preview {
    NavigationStack {
        AuthenticationScreen()
    }
    .environment(AuthSession())
}
