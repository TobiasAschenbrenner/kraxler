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

    private let client: AuthenticationClient
    private var stopObservingAccount: (() -> Void)?

    init(client: AuthenticationClient) {
        self.client = client
    }

    convenience init() {
        self.init(client: .firebase)
    }

    var isAuthenticated: Bool {
        account != nil
    }

    func start() {
        guard stopObservingAccount == nil else {
            return
        }

        guard client.isConfigured() else {
            configurationState = .notConfigured
            return
        }

        stopObservingAccount = client.observeAccount { [weak self] account in
            self?.account = account
            self?.configurationState = .ready
        }
    }

    func signIn(email: String, password: String) async throws {
        guard client.isConfigured() else {
            throw AuthSessionError.notConfigured
        }

        try await client.signIn(email, password)
    }

    func createAccount(email: String, password: String) async throws {
        guard client.isConfigured() else {
            throw AuthSessionError.notConfigured
        }

        try await client.createAccount(email, password)
    }

    func signOut() throws {
        guard client.isConfigured() else {
            throw AuthSessionError.notConfigured
        }

        try client.signOut()
    }

    func idTokenIfAvailable() async throws -> String? {
        guard client.isConfigured() else {
            return nil
        }

        return try await client.idToken()
    }
}
