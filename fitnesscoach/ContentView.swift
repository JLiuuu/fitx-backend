//
//  ContentView.swift
//  fitnesscoach
//
//  Created by Jeremy Liu on 4/27/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            HomeView(viewModel: HomeViewModel(appState: appState))
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            RecoveryView(viewModel: RecoveryViewModel(appState: appState))
                .tabItem {
                    Label("Recovery", systemImage: "figure.strengthtraining.traditional")
                }

            WorkoutView(viewModel: WorkoutViewModel(appState: appState))
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }

            NutritionView(viewModel: NutritionViewModel(appState: appState))
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }

            CoachView(viewModel: CoachViewModel(appState: appState))
                .tabItem {
                    Label("Coach", systemImage: "sparkles")
                }

            ProfileView(viewModel: ProfileViewModel(appState: appState))
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .preferredColorScheme(.dark)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
