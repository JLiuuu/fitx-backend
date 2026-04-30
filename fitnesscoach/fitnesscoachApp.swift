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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .onAppear {
                    appState.startAutomaticHealthSync()
                }
                .onDisappear {
                    appState.stopAutomaticHealthSync()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                appState.startAutomaticHealthSync()
            case .inactive, .background:
                appState.stopAutomaticHealthSync()
            @unknown default:
                appState.stopAutomaticHealthSync()
            }
        }
    }
}
