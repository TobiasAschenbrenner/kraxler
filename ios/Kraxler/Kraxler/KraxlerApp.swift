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
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @State private var authSession: AuthSession
    @State private var connectivity = ConnectivityMonitor()
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
            let usesCaptureFixtures = ProcessInfo.processInfo.arguments.contains("-ui-test-capture")
            modelContainer = try ModelContainer(
                for: OfflineAreaRecord.self,
                OfflineRouteRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: _isDebugAssertConfiguration() && usesCaptureFixtures)
            )
        } catch {
            fatalError("The offline database could not be created: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                apiClient: apiClient,
                modelContainer: modelContainer,
                connectivity: connectivity
            )
            .environment(authSession)
            .modelContainer(modelContainer)
            .preferredColorScheme(appearance.colorScheme)
            .task {
                authSession.start()
#if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-ui-test-offline") {
                    await UITestOfflineScenario.run(connectivity: connectivity, modelContainer: modelContainer)
                    return
                }
#endif
                connectivity.start()
            }
        }
    }

    private var apiClient: APIClient {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-test-capture") {
            return .uiTestCapture { try await authSession.idTokenIfAvailable() }
        }
#endif
        return APIClient { try await authSession.idTokenIfAvailable() }
    }
}
