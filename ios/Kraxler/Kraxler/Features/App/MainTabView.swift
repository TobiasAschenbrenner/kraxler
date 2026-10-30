import SwiftUI

struct MainTabView: View {
    private enum AppTab: Hashable {
        case map
        case library
    }

    let apiClient: APIClient
    let personalRoutesStore: PersonalRoutesStore

    @State private var selectedTab: AppTab = .map

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Map", systemImage: "map", value: .map) {
                MapScreen(
                    apiClient: apiClient,
                    personalRoutesStore: personalRoutesStore
                )
            }

            Tab("Library", systemImage: "bookmark", value: .library) {
                LibraryScreen(
                    apiClient: apiClient,
                    personalRoutesStore: personalRoutesStore
                )
            }
        }
        .tint(.orange)
    }
}
