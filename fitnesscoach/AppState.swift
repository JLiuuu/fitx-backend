import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var dashboard: TodayDashboard
    @Published var recoveryItems: [MuscleRecoveryItem]
    @Published var meals: [MealItem]
    @Published var coachAdvice: CoachAdvice
    @Published var healthStatus: HealthAuthorizationStatus = .notRequested
    @Published var latestHealthSummary: String = "No HealthKit sync yet."

    private let recoveryCalculator = RecoveryCalculator()
    private let healthKitManager = HealthKitManager()
    private let mealScanner = MealScannerService()

    init() {
        self.dashboard = MockData.dashboard
        self.recoveryItems = MockData.recoveryItems
        self.meals = MockData.meals
        self.coachAdvice = MockData.coachAdvice
    }

    func requestHealthAccess() async {
        let result = await healthKitManager.requestAuthorization()
        healthStatus = result.status
        latestHealthSummary = result.summary
    }

    func addWorkout(input: WorkoutInput) {
        let updated = recoveryCalculator.updateRecovery(current: recoveryItems, input: input)
        recoveryItems = updated
        dashboard = dashboard.withReadiness(RecoveryCalculator.readinessScore(from: updated))
        coachAdvice = CoachAdvice.generate(from: dashboard, recoveryItems: updated)
    }

    func scanMeal() async {
        let result = await mealScanner.scanMockMeal()
        meals.insert(result.meal, at: 0)
        dashboard = dashboard.withNutritionDelta(calories: result.meal.calories, protein: result.meal.protein, carbs: result.meal.carbs, fat: result.meal.fat)
        coachAdvice = CoachAdvice.generate(from: dashboard, recoveryItems: recoveryItems)
    }
}
