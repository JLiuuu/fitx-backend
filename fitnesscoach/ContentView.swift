//
//  ContentView.swift
//  fitnesscoach
//
//  Created by Jeremy Liu on 4/27/26.
//

import SwiftUI

struct ContentView: View {
    @State private var dashboard = MockData.dashboard
    @State private var recoveryItems = MockData.recoveryItems
    @State private var meals = MockData.meals
    @State private var coachAdvice = MockData.coachAdvice

    var body: some View {
        TabView {
            HomeView(dashboard: dashboard)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            RecoveryView(items: recoveryItems)
                .tabItem {
                    Label("Recovery", systemImage: "figure.strengthtraining.traditional")
                }

            WorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }

            NutritionView(meals: meals)
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }

            CoachView(advice: coachAdvice)
                .tabItem {
                    Label("Coach", systemImage: "sparkles")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .preferredColorScheme(.dark)
    }
}

struct HomeView: View {
    let dashboard: TodayDashboard

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("Today Readiness") {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(dashboard.readinessScore)/100")
                                    .font(.system(size: 36, weight: .bold))
                                Text(dashboard.statusText)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "bolt.heart.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.green)
                        }
                    }

                    GroupBox("Muscle Recovery Heatmap (Placeholder)") {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .frame(height: 160)
                            .overlay {
                                Text("Front / Back Toggle")
                                    .foregroundStyle(.secondary)
                            }
                    }

                    GroupBox("Today's Training") {
                        Label(dashboard.trainingRecommendation, systemImage: "figure.run")
                    }

                    GroupBox("Nutrition Progress") {
                        VStack(alignment: .leading, spacing: 8) {
                            MetricRow(title: "Calories", value: "\(dashboard.caloriesConsumed) / \(dashboard.calorieGoal) kcal")
                            MetricRow(title: "Protein", value: "\(dashboard.proteinConsumed) / \(dashboard.proteinGoal) g")
                            MetricRow(title: "Carbs", value: "\(dashboard.carbsConsumed) / \(dashboard.carbsGoal) g")
                            MetricRow(title: "Fat", value: "\(dashboard.fatConsumed) / \(dashboard.fatGoal) g")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
        }
    }
}

struct RecoveryView: View {
    let items: [MuscleRecoveryItem]

    var body: some View {
        NavigationStack {
            List(items) { item in
                HStack {
                    Circle()
                        .fill(item.status.color)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading) {
                        Text(item.muscleName)
                        Text("\(item.status.rawValue) • Remaining \(item.remainingHours)h")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(item.fatigueScore)")
                        .fontWeight(.semibold)
                }
            }
            .navigationTitle("Recovery")
        }
    }
}

struct WorkoutView: View {
    @State private var exerciseName = ""
    @State private var sets = "4"
    @State private var reps = "8"
    @State private var weight = "80"
    @State private var rpe = "8"

    var body: some View {
        NavigationStack {
            Form {
                Section("Add Workout (Mock)") {
                    TextField("Exercise", text: $exerciseName)
                    TextField("Sets", text: $sets)
                    TextField("Reps", text: $reps)
                    TextField("Weight (kg)", text: $weight)
                    TextField("RPE", text: $rpe)
                    Button("Save Workout") { }
                }
            }
            .navigationTitle("Workout")
        }
    }
}

struct NutritionView: View {
    let meals: [MealItem]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Button {
                } label: {
                    Label("Scan Meal", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                List(meals) { meal in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(meal.name)
                            .font(.headline)
                        Text("kcal \(meal.calories), P \(meal.protein)g, C \(meal.carbs)g, F \(meal.fat)g")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Nutrition")
        }
    }
}

struct CoachView: View {
    let advice: CoachAdvice

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AdviceCard(title: "Training", content: advice.training)
                    AdviceCard(title: "Nutrition", content: advice.nutrition)
                    AdviceCard(title: "Recovery", content: advice.recovery)
                    AdviceCard(title: "Warning", content: advice.warning)
                }
                .padding()
            }
            .navigationTitle("AI Coach")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("HealthKit") {
                    Button("Authorize Health Data") { }
                    Text("We only use data for recovery estimates, not medical diagnosis.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Goal") {
                    Text("Current Goal: Muscle Gain")
                    Text("Split: Push / Pull / Legs")
                }

                Section("Subscription") {
                    Text("Plan: Free")
                    Text("Scan Quota: 1 / day")
                }
            }
            .navigationTitle("Profile")
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

struct AdviceCard: View {
    let title: String
    let content: String

    var body: some View {
        GroupBox(title) {
            Text(content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.secondary)
        }
    }
}

struct TodayDashboard {
    let readinessScore: Int
    let statusText: String
    let trainingRecommendation: String
    let calorieGoal: Int
    let caloriesConsumed: Int
    let proteinGoal: Int
    let proteinConsumed: Int
    let carbsGoal: Int
    let carbsConsumed: Int
    let fatGoal: Int
    let fatConsumed: Int
}

struct MuscleRecoveryItem: Identifiable {
    let id = UUID()
    let muscleName: String
    let status: RecoveryStatus
    let fatigueScore: Int
    let remainingHours: Int
}

enum RecoveryStatus: String {
    case ready = "Ready"
    case recovering = "Recovering"
    case fatigued = "Fatigued"
    case unknown = "Unknown"

    var color: Color {
        switch self {
        case .ready: .green
        case .recovering: .yellow
        case .fatigued: .red
        case .unknown: .gray
        }
    }
}

struct MealItem: Identifiable {
    let id = UUID()
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct CoachAdvice {
    let training: String
    let nutrition: String
    let recovery: String
    let warning: String
}

enum MockData {
    static let dashboard = TodayDashboard(
        readinessScore: 82,
        statusText: "Ready for Pull Day",
        trainingRecommendation: "Pull Day - Moderate Intensity",
        calorieGoal: 2300,
        caloriesConsumed: 1520,
        proteinGoal: 180,
        proteinConsumed: 118,
        carbsGoal: 250,
        carbsConsumed: 165,
        fatGoal: 70,
        fatConsumed: 45
    )

    static let recoveryItems: [MuscleRecoveryItem] = [
        .init(muscleName: "Chest", status: .recovering, fatigueScore: 62, remainingHours: 18),
        .init(muscleName: "Lats", status: .ready, fatigueScore: 26, remainingHours: 0),
        .init(muscleName: "Quads", status: .fatigued, fatigueScore: 81, remainingHours: 24),
        .init(muscleName: "Hamstrings", status: .recovering, fatigueScore: 59, remainingHours: 16)
    ]

    static let meals: [MealItem] = [
        .init(name: "Chicken Breast + Rice", calories: 620, protein: 48, carbs: 72, fat: 14),
        .init(name: "Greek Yogurt + Berries", calories: 260, protein: 24, carbs: 28, fat: 6)
    ]

    static let coachAdvice = CoachAdvice(
        training: "Recommend Pull Day at moderate intensity. Avoid heavy squats today.",
        nutrition: "You still need ~62g protein. Add a high-protein dinner with moderate carbs.",
        recovery: "Legs need around 24h more recovery. Aim for 7.5h sleep tonight.",
        warning: "If soreness or fatigue worsens, reduce load and prioritize recovery."
    )
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
