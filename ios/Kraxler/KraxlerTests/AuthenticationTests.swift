import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Kraxler

extension KraxlerTests {
    @Test
    func requiresLongPasswordsOnlyWhenCreatingAccounts() async throws {
        #expect(!AccountPasswordPolicy.accepts("shortpass"))
        #expect(AccountPasswordPolicy.accepts("a long passphrase"))
        let authentication = AuthenticationClientSpy(account: nil)
        let session = AuthSession(client: authentication.client)
        session.start()
        await #expect(throws: AccountCreationError.self) {
            try await session.createAccount(email: "climber@example.com", password: "shortpass")
        }
        #expect(session.account == nil)
        try await session.signIn(email: "climber@example.com", password: "oldpass")
        #expect(session.isAuthenticated)
    }

    @Test
    func restoresAnExistingAuthenticationSession() {
        let account = AuthenticatedAccount(
            id: "account-1",
            email: "climber@example.com"
        )
        let authentication = AuthenticationClientSpy(account: account)
        let session = AuthSession(client: authentication.client)

        session.start()

        #expect(session.configurationState == .ready)
        #expect(session.account == account)
        #expect(session.isAuthenticated)
    }

    @Test
    func signsOutAndPublishesTheSignedOutState() throws {
        let authentication = AuthenticationClientSpy(
            account: AuthenticatedAccount(
                id: "account-1",
                email: "climber@example.com"
            )
        )
        let session = AuthSession(client: authentication.client)
        session.start()

        try session.signOut()

        #expect(authentication.signOutCallCount == 1)
        #expect(session.account == nil)
        #expect(!session.isAuthenticated)
    }

    @Test
    func signsInWithGoogleAndPublishesTheAccount() async throws {
        let authentication = AuthenticationClientSpy(account: nil)
        let session = AuthSession(client: authentication.client)
        session.start()

        try await session.signInWithGoogle(
            presentingViewController: UIViewController()
        )

        #expect(authentication.googleSignInCallCount == 1)
        #expect(session.account?.id == "google-account")
        #expect(session.account?.email == "climber@gmail.com")
    }

    @Test
    func signsInWithAppleAndPublishesTheAccount() async throws {
        let authentication = AuthenticationClientSpy(account: nil)
        let session = AuthSession(client: authentication.client)
        session.start()

        try await session.signInWithApple(presentationAnchor: UIWindow())

        #expect(authentication.appleSignInCallCount == 1)
        #expect(session.account?.id == "apple-account")
        #expect(session.account?.email == "climber@icloud.com")
    }

}
