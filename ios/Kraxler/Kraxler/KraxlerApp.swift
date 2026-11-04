// xcode: set sdk=iOS

//
//  KraxlerApp.swift
//  Kraxler
//
//  Created by Tobias Aschenbrenner on 29.10.26.
//

import SwiftData
import SwiftUI

@main
struct KraxlerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authSession: AuthSession
    private let modelContainer: ModelContainer

    init() {
        let authenticationClient: AuthenticationClient
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-test-authenticated") {
            authenticationClient = .uiTest(
                account: AuthenticatedAccount(
                    id: "ui-test-account",
                    email: "climber@example.com"
                )
            )
        } else if ProcessInfo.processInfo.arguments.contains("-ui-test-signed-out") {
            authenticationClient = .uiTest(account: nil)
        } else {
            authenticationClient = .firebase
        }
#else
        authenticationClient = .firebase
#endif
        _authSession = State(
            initialValue: AuthSession(client: authenticationClient)
        )

        do {
            modelContainer = try ModelContainer(
                for: OfflineAreaRecord.self,
                OfflineRouteRecord.self
            )
        } catch {
            fatalError("The offline database could not be created: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                apiClient: APIClient(
                    authTokenProvider: {
                        try await authSession.idTokenIfAvailable()
                    }
                ),
                modelContainer: modelContainer
            )
            .environment(authSession)
            .modelContainer(modelContainer)
            .task {
                authSession.start()
            }
        }
    }
}
