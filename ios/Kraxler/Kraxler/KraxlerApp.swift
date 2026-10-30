// xcode: set sdk=iOS

//
//  KraxlerApp.swift
//  Kraxler
//
//  Created by Tobias Aschenbrenner on 29.10.26.
//

import SwiftUI

@main
struct KraxlerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authSession = AuthSession()

    var body: some Scene {
        WindowGroup {
            ContentView(
                apiClient: APIClient(
                    authTokenProvider: {
                        try await authSession.idTokenIfAvailable()
                    }
                )
            )
            .environment(authSession)
            .task {
                authSession.start()
            }
        }
    }
}
