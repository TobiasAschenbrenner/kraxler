// xcode: set sdk=iOS

//
//  ContentView.swift
//  Kraxler
//
//  Created by Tobias Aschenbrenner on 29.10.26.
//

import SwiftUI

struct ContentView: View {
    private let apiClient: APIClient
    private let showsRouteDetailFixture: Bool
    @State private var personalRoutesStore: PersonalRoutesStore

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
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
            MainTabView(
                apiClient: apiClient,
                personalRoutesStore: personalRoutesStore
            )
        }
    }
}
