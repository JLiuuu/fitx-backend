import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel

    var body: some View {
        let dashboard = viewModel.dashboard
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
    @StateObject var viewModel: RecoveryViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.items) { item in
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
    @StateObject var viewModel: WorkoutViewModel
    @State private var exerciseName = "Chest Press"
    @State private var sets = "4"
    @State private var reps = "8"
    @State private var weight = "80"
    @State private var rpe = "8"
    @State private var saveMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Add Workout") {
                    TextField("Exercise", text: $exerciseName)
                    TextField("Sets", text: $sets)
                    TextField("Reps", text: $reps)
                    TextField("Weight (kg)", text: $weight)
                    TextField("RPE", text: $rpe)
                    Button("Save Workout") {
                        viewModel.saveWorkout(
                            exerciseName: exerciseName,
                            sets: sets,
                            reps: reps,
                            weight: weight,
                            rpe: rpe
                        )
                        saveMessage = "Workout saved and recovery recalculated."
                    }

                    if !saveMessage.isEmpty {
                        Text(saveMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Workout")
        }
    }
}

struct NutritionView: View {
    @StateObject var viewModel: NutritionViewModel
    @State private var isScanning = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Button {
                    Task {
                        isScanning = true
                        await viewModel.scanMeal()
                        isScanning = false
                    }
                } label: {
                    Label(isScanning ? "Scanning..." : "Scan Meal", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(isScanning)

                List(viewModel.meals) { meal in
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
    @StateObject var viewModel: CoachViewModel

    var body: some View {
        let advice = viewModel.advice
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
    @StateObject var viewModel: ProfileViewModel
    @State private var requesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("HealthKit") {
                    Button(requesting ? "Requesting..." : "Authorize Health Data") {
                        Task {
                            requesting = true
                            await viewModel.requestHealthPermission()
                            requesting = false
                        }
                    }
                    .disabled(requesting)

                    Text("Status: \(viewModel.healthStatus.rawValue)")
                    Text(viewModel.latestHealthSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Recovery insights are estimates and not medical diagnosis.")
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
