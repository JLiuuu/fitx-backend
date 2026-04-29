//
//  fitnesscoachApp.swift
//  fitnesscoach
//
//  Created by Jeremy Liu on 4/27/26.
//

import SwiftUI

@main
struct fitnesscoachApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
    }
}
