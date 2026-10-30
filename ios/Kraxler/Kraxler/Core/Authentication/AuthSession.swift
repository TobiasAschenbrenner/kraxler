import FirebaseAuth
import FirebaseCore
import Foundation
import Observation

struct AuthenticatedAccount: Equatable, Sendable {
    let id: String
    let email: String?
}

enum AuthSessionError: Error {
    case notConfigured
    case signedOut
}

@MainActor
@Observable
final class AuthSession {
    enum ConfigurationState: Equatable {
        case loading
        case ready
        case notConfigured
    }

    private(set) var account: AuthenticatedAccount?
    private(set) var configurationState: ConfigurationState = .loading

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    var isAuthenticated: Bool {
        account != nil
    }

    func start() {
        guard authStateHandle == nil else {
            return
        }

        guard FirebaseApp.app() != nil else {
            configurationState = .notConfigured
            return
        }

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.account = user.map {
                    AuthenticatedAccount(id: $0.uid, email: $0.email)
                }
                self?.configurationState = .ready
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        guard FirebaseApp.app() != nil else {
            throw AuthSessionError.notConfigured
        }

        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func createAccount(email: String, password: String) async throws {
        guard FirebaseApp.app() != nil else {
            throw AuthSessionError.notConfigured
        }

        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func signOut() throws {
        guard FirebaseApp.app() != nil else {
            throw AuthSessionError.notConfigured
        }

        try Auth.auth().signOut()
    }

    func idTokenIfAvailable() async throws -> String? {
        guard FirebaseApp.app() != nil else {
            return nil
        }

        guard let user = Auth.auth().currentUser else {
            return nil
        }

        return try await user.getIDToken()
    }
}
