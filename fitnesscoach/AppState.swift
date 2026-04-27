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
    private let persistence = PersistenceService()

    init() {
        if let saved = persistence.load() {
            self.dashboard = saved.dashboard.toDomain()
            self.recoveryItems = saved.recoveryItems.map { $0.toDomain() }
            self.meals = saved.meals.map { $0.toDomain() }
            self.coachAdvice = saved.coachAdvice.toDomain()
            self.healthStatus = HealthAuthorizationStatus(rawValue: saved.healthStatus) ?? .notRequested
            self.latestHealthSummary = saved.latestHealthSummary
            self.lastWorkoutSummary = saved.lastWorkoutSummary
            self.lastMealDetectionSummary = saved.lastMealDetectionSummary
            self.subscriptionPlan = SubscriptionPlan(rawValue: saved.subscriptionPlan) ?? .free
            self.dailyMealScanCount = saved.dailyMealScanCount
            self.mealScanDailyLimit = saved.mealScanDailyLimit
            self.lastSubscriptionMessage = saved.lastSubscriptionMessage
        } else {
            self.dashboard = MockData.dashboard
            self.recoveryItems = MockData.recoveryItems
            self.meals = MockData.meals
            self.coachAdvice = MockData.coachAdvice
            refreshCoachAdvice()
            persist()
        }
    }

    func requestHealthAccess() async {
        let result = await healthKitManager.requestAuthorization()
        healthStatus = result.status
        latestHealthSummary = result.summary
        persist()
    }

    func addWorkout(input: WorkoutInput) {
        let result = recoveryCalculator.updateRecovery(current: recoveryItems, input: input)
        let updated = result.items
        recoveryItems = updated
        lastWorkoutSummary = result.summary
        dashboard = dashboard.withReadiness(RecoveryCalculator.readinessScore(from: updated))
        refreshCoachAdvice()
        persist()
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
        persist()
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
        persist()
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

    private func persist() {
        persistence.save(
            PersistedState(
                dashboard: dashboard.toDTO(),
                recoveryItems: recoveryItems.map { $0.toDTO() },
                meals: meals.map { $0.toDTO() },
                coachAdvice: coachAdvice.toDTO(),
                healthStatus: healthStatus.rawValue,
                latestHealthSummary: latestHealthSummary,
                lastWorkoutSummary: lastWorkoutSummary,
                lastMealDetectionSummary: lastMealDetectionSummary,
                subscriptionPlan: subscriptionPlan.rawValue,
                dailyMealScanCount: dailyMealScanCount,
                mealScanDailyLimit: mealScanDailyLimit,
                lastSubscriptionMessage: lastSubscriptionMessage
            )
        )
    }
}

private extension TodayDashboard {
    func toDTO() -> DashboardDTO {
        DashboardDTO(
            readinessScore: readinessScore,
            statusText: statusText,
            trainingRecommendation: trainingRecommendation,
            calorieGoal: calorieGoal,
            caloriesConsumed: caloriesConsumed,
            proteinGoal: proteinGoal,
            proteinConsumed: proteinConsumed,
            carbsGoal: carbsGoal,
            carbsConsumed: carbsConsumed,
            fatGoal: fatGoal,
            fatConsumed: fatConsumed
        )
    }
}

private extension DashboardDTO {
    func toDomain() -> TodayDashboard {
        TodayDashboard(
            readinessScore: readinessScore,
            statusText: statusText,
            trainingRecommendation: trainingRecommendation,
            calorieGoal: calorieGoal,
            caloriesConsumed: caloriesConsumed,
            proteinGoal: proteinGoal,
            proteinConsumed: proteinConsumed,
            carbsGoal: carbsGoal,
            carbsConsumed: carbsConsumed,
            fatGoal: fatGoal,
            fatConsumed: fatConsumed
        )
    }
}

private extension MuscleRecoveryItem {
    func toDTO() -> MuscleRecoveryDTO {
        MuscleRecoveryDTO(
            muscleName: muscleName,
            status: status.rawValue,
            fatigueScore: fatigueScore,
            remainingHours: remainingHours
        )
    }
}

private extension MuscleRecoveryDTO {
    func toDomain() -> MuscleRecoveryItem {
        MuscleRecoveryItem(
            muscleName: muscleName,
            status: RecoveryStatus(rawValue: status) ?? .unknown,
            fatigueScore: fatigueScore,
            remainingHours: remainingHours
        )
    }
}

private extension MealItem {
    func toDTO() -> MealDTO {
        MealDTO(
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            confidence: confidence,
            needsConfirmation: needsConfirmation,
            questions: questions
        )
    }
}

private extension MealDTO {
    func toDomain() -> MealItem {
        MealItem(
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            confidence: confidence,
            needsConfirmation: needsConfirmation,
            questions: questions
        )
    }
}

private extension CoachAdvice {
    func toDTO() -> CoachAdviceDTO {
        CoachAdviceDTO(
            readinessScore: readinessScore,
            training: training,
            nutrition: nutrition,
            recovery: recovery,
            warning: warning,
            missingData: missingData
        )
    }
}

private extension CoachAdviceDTO {
    func toDomain() -> CoachAdvice {
        CoachAdvice(
            readinessScore: readinessScore,
            training: training,
            nutrition: nutrition,
            recovery: recovery,
            warning: warning,
            missingData: missingData
        )
    }
}
