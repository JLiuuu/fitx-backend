import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var dashboard: TodayDashboard
    @Published var recoveryItems: [MuscleRecoveryItem]
    @Published var meals: [MealItem]
    @Published var coachAdvice: CoachAdvice
    @Published var subscriptionPlan: SubscriptionPlan = .free
    @Published var dailyMealScanCount: Int = 0
    @Published var mealScanDailyLimit: Int = 1
    @Published var lastSubscriptionMessage: String = "Free plan active."
    @Published var healthStatus: HealthAuthorizationStatus = .notRequested
    @Published var latestHealthSummary: String = "No HealthKit sync yet."
    @Published var lastWorkoutSummary: String = "No workout saved yet."
    @Published var lastMealDetectionSummary: String = "No meal scan yet."

    private let recoveryCalculator = RecoveryCalculator()
    private let healthKitManager = HealthKitManager()
    private let mealScanner = MealScannerService()
    private let coachEngine = CoachEngine()

    init() {
        self.dashboard = MockData.dashboard
        self.recoveryItems = MockData.recoveryItems
        self.meals = MockData.meals
        self.coachAdvice = MockData.coachAdvice
        refreshCoachAdvice()
    }

    func requestHealthAccess() async {
        let result = await healthKitManager.requestAuthorization()
        healthStatus = result.status
        latestHealthSummary = result.summary
    }

    func addWorkout(input: WorkoutInput) {
        let result = recoveryCalculator.updateRecovery(current: recoveryItems, input: input)
        let updated = result.items
        recoveryItems = updated
        lastWorkoutSummary = result.summary
        dashboard = dashboard.withReadiness(RecoveryCalculator.readinessScore(from: updated))
        refreshCoachAdvice()
    }

    func scanMeal() async {
        guard canScanMeal() else {
            lastMealDetectionSummary = "Daily scan quota reached. Upgrade to Pro for unlimited scans."
            return
        }
        let result = await mealScanner.scanMockMeal()
        meals.insert(result.meal, at: 0)
        dailyMealScanCount += 1
        if result.foods.isEmpty {
            lastMealDetectionSummary = "No foods detected."
        } else {
            let top = result.foods.prefix(3).map { "\($0.name) \($0.estimatedWeightGram)g" }.joined(separator: ", ")
            lastMealDetectionSummary = "Detected: \(top)"
        }
        dashboard = dashboard.withNutritionDelta(calories: result.meal.calories, protein: result.meal.protein, carbs: result.meal.carbs, fat: result.meal.fat)
        refreshCoachAdvice()
    }

    func refreshCoachAdvice() {
        coachAdvice = coachEngine.generate(
            context: CoachContext(
                dashboard: dashboard,
                recoveryItems: recoveryItems,
                mealsToday: meals.count,
                healthStatus: healthStatus,
                subscriptionPlan: subscriptionPlan
            )
        )
    }

    func setSubscriptionPlan(_ plan: SubscriptionPlan) {
        subscriptionPlan = plan
        mealScanDailyLimit = plan == .pro ? Int.max : 1
        lastSubscriptionMessage = plan == .pro
            ? "Pro plan active. Unlimited meal scans enabled."
            : "Free plan active. 1 meal scan per day."
        refreshCoachAdvice()
    }

    func canScanMeal() -> Bool {
        subscriptionPlan == .pro || dailyMealScanCount < mealScanDailyLimit
    }

    func remainingMealScansText() -> String {
        if subscriptionPlan == .pro {
            return "Unlimited scans"
        }
        return "\(max(0, mealScanDailyLimit - dailyMealScanCount)) / \(mealScanDailyLimit) scans left today"
    }
}
