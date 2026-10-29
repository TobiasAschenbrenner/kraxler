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

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    var body: some View {
        MapScreen(apiClient: apiClient)
    }
}
