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
    @State private var authSession = AuthSession()
    private let modelContainer: ModelContainer

    init() {
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
