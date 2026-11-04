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
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            KraxlerScreenBackground()

            if authSession.configurationState == .notConfigured {
                ContentUnavailableView {
                    Label("Account setup pending", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("Firebase still needs to be connected before accounts can be used.")
                }
            } else {
                ScrollView {
                    VStack(spacing: 28) {
                        header
                        accountCard
                    }
                    .padding(.horizontal, KraxlerDesign.pagePadding)
                    .padding(.top, 40)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: mode)
        .accessibilityIdentifier("authentication-screen")
    }

    private var header: some View {
        VStack(spacing: 14) {
            KraxlerBrandMark(size: 76)

            Text("Kraxler")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text("Find climbs. Go offline.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var accountCard: some View {
        VStack(spacing: 20) {
            Picker("Account action", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("authentication-mode-picker")

            VStack(spacing: 12) {
                authenticationField(systemImage: "envelope.fill") {
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

                authenticationField(systemImage: "lock.fill") {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("authentication-error")
            }

            Button {
                Task {
                    await submit()
                }
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(mode.rawValue)
                    }
                }
                .frame(height: 22)
            }
            .buttonStyle(KraxlerPrimaryButtonStyle())
            .disabled(!canSubmit || isSubmitting)
            .opacity(canSubmit ? 1 : 0.46)
            .accessibilityIdentifier("authentication-submit")
        }
        .padding(20)
        .background(
            Color(.secondarySystemGroupedBackground).opacity(0.9),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .shadow(color: .black.opacity(0.06), radius: 24, y: 12)
    }

    private func authenticationField<FieldContent: View>(
        systemImage: String,
        @ViewBuilder content: () -> FieldContent
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(KraxlerDesign.accent)
                .frame(width: 22)

            content()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(
            Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
        )
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
