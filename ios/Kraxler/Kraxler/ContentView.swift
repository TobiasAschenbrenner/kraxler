// xcode: set sdk=iOS

//
//  ContentView.swift
//  Kraxler
//
//  Created by Tobias Aschenbrenner on 29.10.26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    private let apiClient: APIClient
    private let climbingRepository: ClimbingRepository
    private let showsRouteDetailFixture: Bool
    @State private var personalRoutesStore: PersonalRoutesStore
    @State private var offlineDownloadsStore: OfflineDownloadsStore
    @Environment(AuthSession.self) private var authSession

    init(
        apiClient: APIClient = APIClient(),
        modelContainer: ModelContainer
    ) {
        self.apiClient = apiClient
        let offlineStore = OfflineClimbingStore(modelContainer: modelContainer)
        climbingRepository = ClimbingRepository(
            apiClient: apiClient,
            offlineStore: offlineStore
        )
        _offlineDownloadsStore = State(
            initialValue: OfflineDownloadsStore(
                climbingRepository: climbingRepository,
                offlineMapStore: MapboxOfflineMapStore()
            )
        )
        _personalRoutesStore = State(
            initialValue: PersonalRoutesStore(apiClient: apiClient)
        )
#if DEBUG
        showsRouteDetailFixture = ProcessInfo.processInfo.arguments.contains(
            "-ui-test-route-detail"
        )
#else
        showsRouteDetailFixture = false
#endif
    }

    @ViewBuilder
    var body: some View {
        if showsRouteDetailFixture {
#if DEBUG
            NavigationStack {
                RouteDetailScreen(
                    routeID: ClimbingRoute.routeDetailFixture.id,
                    initialRoute: .routeDetailFixture,
                    loadsRemoteRoute: false
                )
            }
#endif
        } else {
            authenticatedContent
                .onChange(of: authSession.account) { _, account in
                    if account == nil {
                        personalRoutesStore.reset()
                    }
                }
        }
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        switch authSession.configurationState {
        case .loading:
            ZStack {
                KraxlerScreenBackground(showsTopography: true)

                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        Text("Kraxler")
                            .font(.largeTitle.bold())
                        KraxlerBrandMark(size: 44)
                    }
                    ProgressView()
                }
            }
            .accessibilityIdentifier("authentication-loading")

        case .notConfigured:
            NavigationStack {
                AuthenticationScreen()
            }

        case .ready where !authSession.isAuthenticated:
            NavigationStack {
                AuthenticationScreen()
            }

        case .ready:
            MainTabView(
                personalRoutesStore: personalRoutesStore,
                climbingRepository: climbingRepository,
                offlineDownloadsStore: offlineDownloadsStore
            )
            .accessibilityIdentifier("authenticated-app")
        }
    }
}
