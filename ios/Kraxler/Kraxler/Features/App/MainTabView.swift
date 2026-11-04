import SwiftUI

struct MainTabView: View {
    private enum AppTab: Hashable {
        case map
        case library
        case profile
    }

    let personalRoutesStore: PersonalRoutesStore
    let climbingRepository: ClimbingRepository
    let offlineDownloadsStore: OfflineDownloadsStore

    @State private var selectedTab: AppTab = .map

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Map", systemImage: "map", value: .map) {
                MapScreen(
                    personalRoutesStore: personalRoutesStore,
                    climbingRepository: climbingRepository,
                    offlineDownloadsStore: offlineDownloadsStore
                )
            }

            Tab("Library", systemImage: "bookmark", value: .library) {
                LibraryScreen(
                    personalRoutesStore: personalRoutesStore,
                    climbingRepository: climbingRepository
                )
            }

            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                ProfileScreen(
                    offlineDownloadsStore: offlineDownloadsStore
                )
            }
        }
        .tint(.orange)
        .task {
            await offlineDownloadsStore.load()
        }
    }
}
