import SwiftUI

struct MainTabView: View {
    private enum AppTab: Hashable {
        case map
        case library
    }

    let apiClient: APIClient
    let personalRoutesStore: PersonalRoutesStore
    let climbingRepository: ClimbingRepository

    @State private var selectedTab: AppTab = .map

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Map", systemImage: "map", value: .map) {
                MapScreen(
                    personalRoutesStore: personalRoutesStore,
                    climbingRepository: climbingRepository
                )
            }

            Tab("Library", systemImage: "bookmark", value: .library) {
                LibraryScreen(
                    apiClient: apiClient,
                    personalRoutesStore: personalRoutesStore,
                    climbingRepository: climbingRepository
                )
            }
        }
        .tint(.orange)
    }
}
