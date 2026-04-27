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
    @Published var useLiveBackend: Bool = false
    @Published var backendStatusMessage: String = "Using mock backend."
    @Published var healthStatus: HealthAuthorizationStatus = .notRequested
    @Published var latestHealthSummary: String = "No HealthKit sync yet."
    @Published var lastWorkoutSummary: String = "No workout saved yet."
    @Published var lastMealDetectionSummary: String = "No meal scan yet."

    private let recoveryCalculator = RecoveryCalculator()
    private let healthKitManager = HealthKitManager()
    private let mealScanner = MealScannerService()
    private let coachEngine = CoachEngine()
    private let persistence = PersistenceService()
    private let apiClient = APIClient()
    private let subscriptionManager = SubscriptionManager()
    private let userID = "demo-user"

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
            self.useLiveBackend = saved.useLiveBackend
            self.backendStatusMessage = saved.backendStatusMessage
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
        let result: MealScanResult
        if useLiveBackend {
            do {
                result = try await apiClient.scanMeal(userID: userID, mealType: "dinner")
                backendStatusMessage = "Live backend scan succeeded."
            } catch {
                result = await mealScanner.scanMockMeal()
                backendStatusMessage = "Live backend scan failed. Fallback to mock."
            }
        } else {
            result = await mealScanner.scanMockMeal()
            backendStatusMessage = "Using mock backend scan."
        }
        meals.insert(result.meal, at: 0)
        dailyMealScanCount += 1
        if result.foods.isEmpty {
            lastMealDetectionSummary = "No foods detected."
        } else {
            let top = result.foods.prefix(3).map { "\($0.name) \($0.estimatedWeightGram)g" }.joined(separator: ", ")
            lastMealDetectionSummary = "Detected: \(top)"
        }
        dashboard = dashboard.withNutritionDelta(calories: result.meal.calories, protein: result.meal.protein, carbs: result.meal.carbs, fat: result.meal.fat)
        await refreshCoachAdvice()
        persist()
    }

    func refreshCoachAdvice() {
        Task {
            await refreshCoachAdvice()
        }
    }

    func refreshCoachAdvice() async {
        if useLiveBackend {
            do {
                coachAdvice = try await apiClient.fetchTodayCoach(
                    userID: userID,
                    dashboard: dashboard,
                    recoveryItems: recoveryItems,
                    mealsCount: meals.count
                )
                backendStatusMessage = "Live backend coach advice succeeded."
                return
            } catch {
                backendStatusMessage = "Live backend coach advice failed. Fallback to local engine."
            }
        }
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

    func runBetaLoop() async {
        await requestHealthAccess()
        addWorkout(
            input: WorkoutInput(
                exerciseName: "Pull-up",
                sets: 4,
                reps: 8,
                weight: 0,
                rpe: 8
            )
        )
        await scanMeal()
        await refreshCoachAdvice()
    }

    func syncSubscriptionWithStoreKit() async {
        await subscriptionManager.refreshEntitlements()
        setSubscriptionPlan(subscriptionManager.activePlan)
        lastSubscriptionMessage = subscriptionManager.lastSyncStatus
        persist()
    }

    func setLiveBackendEnabled(_ enabled: Bool) {
        useLiveBackend = enabled
        backendStatusMessage = enabled ? "Live backend enabled." : "Mock backend enabled."
        persist()
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
                lastSubscriptionMessage: lastSubscriptionMessage,
                useLiveBackend: useLiveBackend,
                backendStatusMessage: backendStatusMessage
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
