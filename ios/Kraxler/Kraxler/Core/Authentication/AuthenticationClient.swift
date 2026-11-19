import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import Security
import UIKit

enum AuthenticationClientError: Error, Equatable {
    case cancelled
    case appleCredentialMissing
    case appleIDTokenInvalid
    case appleIDTokenMissing
    case googleClientIDMissing
    case googleIDTokenMissing
}

@MainActor
struct AuthenticationClient {
    typealias AccountObserver = @MainActor (AuthenticatedAccount?) -> Void

    let isConfigured: () -> Bool
    let observeAccount: (@escaping AccountObserver) -> () -> Void
    let signIn: (_ email: String, _ password: String) async throws -> Void
    let signInWithApple: (_ presentationAnchor: ASPresentationAnchor) async throws -> Void
    let signInWithGoogle: (_ presentingViewController: UIViewController) async throws -> Void
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
        signInWithApple: { presentationAnchor in
            let nonce = try AppleSignInNonce.make()
            let coordinator = AppleSignInCoordinator(
                presentationAnchor: presentationAnchor,
                nonce: nonce
            )
            let appleCredential = try await coordinator.authorize()

            guard let identityToken = appleCredential.identityToken else {
                throw AuthenticationClientError.appleIDTokenMissing
            }

            guard let idToken = String(data: identityToken, encoding: .utf8) else {
                throw AuthenticationClientError.appleIDTokenInvalid
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: appleCredential.fullName
            )
            try await Auth.auth().signIn(with: credential)
        },
        signInWithGoogle: { presentingViewController in
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw AuthenticationClientError.googleClientIDMissing
            }

            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            let result: GIDSignInResult
            do {
                result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: presentingViewController
                )
            } catch let error as GIDSignInError where error.code == .canceled {
                throw AuthenticationClientError.cancelled
            }

            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthenticationClientError.googleIDTokenMissing
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            try await Auth.auth().signIn(with: credential)
        },
        createAccount: { email, password in
            try await Auth.auth().createUser(withEmail: email, password: password)
        },
        signOut: {
            GIDSignIn.sharedInstance.signOut()
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
            signInWithApple: { [self] _ in
                updateAccount(
                    AuthenticatedAccount(
                        id: "ui-test-apple-account",
                        email: "climber@icloud.com"
                    )
                )
            },
            signInWithGoogle: { [self] _ in
                updateAccount(
                    AuthenticatedAccount(
                        id: "ui-test-google-account",
                        email: "climber@gmail.com"
                    )
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

private enum AppleSignInNonce {
    static func make(length: Int = 32) throws -> String {
        precondition(length > 0)

        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

            guard status == errSecSuccess else {
                throw NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(status)
                )
            }

            for randomByte in randomBytes where remainingLength > 0 {
                if randomByte < characters.count {
                    result.append(characters[Int(randomByte)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

@MainActor
private final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private let presentationAnchor: ASPresentationAnchor
    private let nonce: String
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var authorizationController: ASAuthorizationController?

    init(presentationAnchor: ASPresentationAnchor, nonce: String) {
        self.presentationAnchor = presentationAnchor
        self.nonce = nonce
    }

    func authorize() async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            authorizationController = controller
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(throwing: AuthenticationClientError.appleCredentialMissing)
            return
        }

        finish(returning: credential)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            finish(throwing: AuthenticationClientError.cancelled)
        } else {
            finish(throwing: error)
        }
    }

    private func finish(returning credential: ASAuthorizationAppleIDCredential) {
        continuation?.resume(returning: credential)
        clearRequest()
    }

    private func finish(throwing error: Error) {
        continuation?.resume(throwing: error)
        clearRequest()
    }

    private func clearRequest() {
        continuation = nil
        authorizationController = nil
    }
}
