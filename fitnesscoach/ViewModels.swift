import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    private let appState: AppState
    init(appState: AppState) { self.appState = appState }
    var dashboard: TodayDashboard { appState.dashboard }
}

@MainActor
final class RecoveryViewModel: ObservableObject {
    private let appState: AppState
    init(appState: AppState) { self.appState = appState }
    var items: [MuscleRecoveryItem] { appState.recoveryItems }
    var lastWorkoutSummary: String { appState.lastWorkoutSummary }
    var readinessScore: Int { appState.dashboard.readinessScore }
}

@MainActor
final class WorkoutViewModel: ObservableObject {
    private let appState: AppState
    init(appState: AppState) { self.appState = appState }

    func saveWorkout(exerciseName: String, sets: String, reps: String, weight: String, rpe: String) {
        let workout = WorkoutInput(
            exerciseName: exerciseName,
            sets: Int(sets) ?? 0,
            reps: Int(reps) ?? 0,
            weight: Double(weight) ?? 0,
            rpe: Int(rpe) ?? 7
        )
        appState.addWorkout(input: workout)
    }
}

@MainActor
final class NutritionViewModel: ObservableObject {
    private let appState: AppState
    init(appState: AppState) { self.appState = appState }
    var meals: [MealItem] { appState.meals }
    var latestDetectionSummary: String { appState.lastMealDetectionSummary }

    func scanMeal() async {
        await appState.scanMeal()
    }
}

@MainActor
final class CoachViewModel: ObservableObject {
    private let appState: AppState
    init(appState: AppState) { self.appState = appState }
    var advice: CoachAdvice { appState.coachAdvice }

    func refreshCoach() {
        appState.refreshCoachAdvice()
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    private let appState: AppState
    init(appState: AppState) { self.appState = appState }

    var healthStatus: HealthAuthorizationStatus { appState.healthStatus }
    var latestHealthSummary: String { appState.latestHealthSummary }

    func requestHealthPermission() async {
        await appState.requestHealthAccess()
    }
}
