import FirebaseAuth
import FirebaseCore
import Foundation

@MainActor
struct AuthenticationClient {
    typealias AccountObserver = @MainActor (AuthenticatedAccount?) -> Void

    let isConfigured: () -> Bool
    let observeAccount: (@escaping AccountObserver) -> () -> Void
    let signIn: (_ email: String, _ password: String) async throws -> Void
    let createAccount: (_ email: String, _ password: String) async throws -> Void
    let signOut: () throws -> Void
    let idToken: () async throws -> String?
}

extension AuthenticationClient {
    static let firebase = AuthenticationClient(
        isConfigured: {
            FirebaseApp.app() != nil
        },
        observeAccount: { observer in
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                let account = user.map {
                    AuthenticatedAccount(id: $0.uid, email: $0.email)
                }

                Task { @MainActor in
                    observer(account)
                }
            }

            return {
                Auth.auth().removeStateDidChangeListener(handle)
            }
        },
        signIn: { email, password in
            try await Auth.auth().signIn(withEmail: email, password: password)
        },
        createAccount: { email, password in
            try await Auth.auth().createUser(withEmail: email, password: password)
        },
        signOut: {
            try Auth.auth().signOut()
        },
        idToken: {
            guard let user = Auth.auth().currentUser else {
                return nil
            }

            return try await user.getIDToken()
        }
    )
}

#if DEBUG
extension AuthenticationClient {
    static func uiTest(account: AuthenticatedAccount?) -> AuthenticationClient {
        let state = UITestAuthenticationState(account: account)
        return state.client
    }
}

@MainActor
private final class UITestAuthenticationState {
    private var account: AuthenticatedAccount?
    private var observer: AuthenticationClient.AccountObserver?

    init(account: AuthenticatedAccount?) {
        self.account = account
    }

    var client: AuthenticationClient {
        AuthenticationClient(
            isConfigured: { true },
            observeAccount: { [self] observer in
                self.observer = observer
                observer(account)
                return { [weak self] in
                    self?.observer = nil
                }
            },
            signIn: { [self] email, _ in
                updateAccount(
                    AuthenticatedAccount(id: "ui-test-account", email: email)
                )
            },
            createAccount: { [self] email, _ in
                updateAccount(
                    AuthenticatedAccount(id: "ui-test-account", email: email)
                )
            },
            signOut: { [self] in
                updateAccount(nil)
            },
            idToken: { [self] in
                account == nil ? nil : "ui-test-token"
            }
        )
    }

    private func updateAccount(_ account: AuthenticatedAccount?) {
        self.account = account
        observer?(account)
    }
}
#endif
