import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var authMethod: String = ""
    @Published var authIdentifier: String = ""
    @Published var userProfile: UserProfile?
    @Published var plannedTrainingWeekdays: Set<Int> = [2, 4, 6] // Mon/Wed/Fri
    @Published var dashboard: TodayDashboard
    @Published var recoveryItems: [MuscleRecoveryItem]
    @Published var workoutLogs: [WorkoutLogItem]
    @Published var meals: [MealItem]
    @Published var coachAdvice: CoachAdvice
    @Published var subscriptionPlan: SubscriptionPlan = .free
    @Published var dailyMealScanCount: Int = 0
    @Published var mealScanDailyLimit: Int = 1
    @Published var lastSubscriptionMessage: String = "Free plan active."
    @Published var useLiveBackend: Bool = false
    @Published var backendStatusMessage: String = "Using local mock backend."
    @Published var showSignalExplanations: Bool = true
    @Published var healthStatus: HealthAuthorizationStatus = .notRequested
    @Published var latestHealthSummary: String = "Health data has not been synced yet."
    @Published var todayExerciseMinutes: Int = 0
    @Published var healthInsights: [String] = []
    @Published var todayActiveEnergyKcal: Int = 0
    @Published var todayStepCount: Int = 0
    @Published var todayDistanceKm: Double = 0
    @Published var todayHRVms: Int = 0
    @Published var todaySleepHours: Double = 0
    @Published var todayAvgHeartRate: Int = 0
    @Published var todayMinHeartRate: Int = 0
    @Published var todayMaxHeartRate: Int = 0
    @Published var voicePermissionStatus: VoicePermissionStatus = .notRequested
    @Published var voicePermissionMessage: String = "Voice permissions not requested."
    @Published var lastWorkoutSummary: String = "No workouts logged yet."
    @Published var lastMealDetectionSummary: String = "No meal scans yet."
    @Published var aiAssistantDailyCount: Int = 0
    @Published var aiAssistantLastUsedDay: String = ""
    // When an exercise name isn't matched by the built-in contribution map,
    // we can learn/store a custom distribution so fatigue gets attributed better next time.
    @Published var customExerciseContributions: [String: [String: Double]] = [:]
    private var contributionLearningInProgress: Set<String> = []

    private let recoveryCalculator = RecoveryCalculator()
    private let healthKitManager = HealthKitManager()
    private let mealScanner = MealScannerService()
    private let coachEngine = CoachEngine()
    private let observability = ObservabilityService()
    private let socialOAuthService = SocialOAuthService()
    private let voicePermissionManager = VoicePermissionManager()
    private let persistence = PersistenceService()
    private let apiClient = APIClient()
    private let subscriptionManager = SubscriptionManager()
    private let userID = "demo-user"
    private var lastHealthReadinessScore: Int?
    private var currentDayKey: String
    private var dayChangedObserver: NSObjectProtocol?
    private var healthAutoSyncTask: Task<Void, Never>?

    init() {
        currentDayKey = AppState.dayKey(for: Date())
        if let saved = persistence.load() {
            self.isAuthenticated = saved.isAuthenticated ?? false
            self.hasCompletedOnboarding = saved.hasCompletedOnboarding ?? false
            self.authMethod = saved.authMethod ?? ""
            self.authIdentifier = saved.authIdentifier ?? ""
            self.userProfile = saved.userProfile
            self.plannedTrainingWeekdays = Set(saved.plannedTrainingWeekdays ?? [2, 4, 6])
            self.dashboard = saved.dashboard.toDomain()
            self.recoveryItems = Self.normalizedRecoveryItems(from: saved.recoveryItems.map { $0.toDomain() })
            self.workoutLogs = (saved.workoutLogs ?? []).map { $0.toDomain() }.sorted { $0.loggedAt > $1.loggedAt }
            self.meals = saved.meals.map { $0.toDomain() }
            self.coachAdvice = saved.coachAdvice.toDomain()
            self.healthStatus = HealthAuthorizationStatus(rawValue: saved.healthStatus) ?? .notRequested
            self.latestHealthSummary = saved.latestHealthSummary
            self.healthInsights = saved.healthInsights ?? []
            self.lastWorkoutSummary = saved.lastWorkoutSummary
            self.lastMealDetectionSummary = saved.lastMealDetectionSummary
            self.subscriptionPlan = SubscriptionPlan(rawValue: saved.subscriptionPlan) ?? .free
            self.dailyMealScanCount = saved.dailyMealScanCount
            self.mealScanDailyLimit = saved.mealScanDailyLimit
            self.lastSubscriptionMessage = saved.lastSubscriptionMessage
            self.useLiveBackend = saved.useLiveBackend
            self.backendStatusMessage = saved.backendStatusMessage
            self.showSignalExplanations = saved.showSignalExplanations ?? true
            self.aiAssistantDailyCount = saved.aiAssistantDailyCount ?? 0
            self.aiAssistantLastUsedDay = saved.aiAssistantLastUsedDay ?? Self.dayKey(for: Date())
            self.customExerciseContributions = saved.customExerciseContributions ?? [:]
            if self.workoutLogs.isEmpty {
                self.recoveryItems = Self.emptyRecoveryItems()
                self.lastWorkoutSummary = "No workouts logged yet."
            }
            syncTodayNutritionFromMeals()
            if let profile = self.userProfile {
                applyNutritionTargets(for: profile)
            }
            recomputeDashboardReadiness()
            currentDayKey = Self.dayKey(for: Date())
        } else {
            let defaultDashboard = Self.defaultDashboard()
            let defaultRecovery = Self.emptyRecoveryItems()
            self.dashboard = defaultDashboard
            self.recoveryItems = defaultRecovery
            self.workoutLogs = []
            self.meals = []
            self.coachAdvice = CoachAdvice.generate(from: defaultDashboard, recoveryItems: defaultRecovery)
            syncTodayNutritionFromMeals()
            refreshCoachAdvice()
            currentDayKey = Self.dayKey(for: Date())
            persist()
        }
        setupDayChangedObserver()
    }

    deinit {
        if let dayChangedObserver {
            NotificationCenter.default.removeObserver(dayChangedObserver)
        }
        healthAutoSyncTask?.cancel()
    }

    func startAutomaticHealthSync(intervalSeconds: UInt64 = 30) {
        healthAutoSyncTask?.cancel()
        healthAutoSyncTask = Task { [weak self] in
            guard let self else { return }
            await self.requestHealthAccess()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
                if Task.isCancelled { break }
                await self.requestHealthAccess()
            }
        }
    }

    func stopAutomaticHealthSync() {
        healthAutoSyncTask?.cancel()
        healthAutoSyncTask = nil
    }

    func loginWithEmail(_ identifier: String) {
        authMethod = "email"
        authIdentifier = identifier
        isAuthenticated = true
        observability.track("auth_login_email")
        persist()
    }

    func registerWithEmail(_ identifier: String) {
        authMethod = "email"
        authIdentifier = identifier
        isAuthenticated = true
        observability.track("auth_register_email")
        persist()
    }

    func signInWithProvider(_ provider: String) {
        authMethod = provider
        authIdentifier = "\(provider)-user"
        isAuthenticated = true
        observability.track("auth_login_provider", metadata: ["provider": provider])
        persist()
    }

    func signInWithOAuthProvider(_ provider: SocialOAuthProvider) async throws {
        let authCode = try await socialOAuthService.authorize(provider: provider)
        authMethod = provider.rawValue
        authIdentifier = "\(provider.rawValue)-\(authCode.prefix(8))"
        isAuthenticated = true
        observability.track("auth_login_provider", metadata: ["provider": provider.rawValue, "oauth": "true"])
        persist()
    }

    func signInWithApple(userID: String, email: String?) {
        authMethod = "apple"
        if let email, !email.isEmpty {
            authIdentifier = email
        } else {
            authIdentifier = userID
        }
        isAuthenticated = true
        observability.track("auth_login_provider", metadata: ["provider": "apple"])
        persist()
    }

    func completeOnboarding(profile: UserProfile) {
        userProfile = profile
        applyNutritionTargets(for: profile)
        hasCompletedOnboarding = true
        observability.track(
            "onboarding_complete",
            metadata: [
                "goal": profile.primaryGoal.rawValue,
                "activityLevel": profile.activityLevel.rawValue
            ]
        )
        persist()
    }

    func updatePrimaryGoal(_ goal: PrimaryGoal) {
        guard let profile = userProfile else { return }
        let defaultDelta = goal == .muscleGain ? 700 : -700
        userProfile = UserProfile(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            preferredHeightUnit: profile.preferredHeightUnit,
            preferredWeightUnit: profile.preferredWeightUnit,
            primaryGoal: goal,
            activityLevel: profile.activityLevel,
            calorieDeltaGoalKcal: profile.calorieDeltaGoalKcal == 0 ? defaultDelta : profile.calorieDeltaGoalKcal,
            dailyWorkoutGoalKcal: profile.dailyWorkoutGoalKcal
        )
        applyNutritionTargets(for: userProfile!)
        observability.track("profile_goal_updated", metadata: ["goal": goal.rawValue])
        persist()
    }

    func updateActivityLevel(_ level: ActivityLevel) {
        guard let profile = userProfile else { return }
        userProfile = UserProfile(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            preferredHeightUnit: profile.preferredHeightUnit,
            preferredWeightUnit: profile.preferredWeightUnit,
            primaryGoal: profile.primaryGoal,
            activityLevel: level,
            calorieDeltaGoalKcal: profile.calorieDeltaGoalKcal,
            dailyWorkoutGoalKcal: profile.dailyWorkoutGoalKcal
        )
        applyNutritionTargets(for: userProfile!)
        observability.track("profile_activity_level_updated", metadata: ["level": level.rawValue])
        persist()
    }

    func updateCalorieDeltaGoal(_ delta: Int) {
        guard let profile = userProfile else { return }
        userProfile = UserProfile(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            preferredHeightUnit: profile.preferredHeightUnit,
            preferredWeightUnit: profile.preferredWeightUnit,
            primaryGoal: profile.primaryGoal,
            activityLevel: profile.activityLevel,
            calorieDeltaGoalKcal: delta,
            dailyWorkoutGoalKcal: profile.dailyWorkoutGoalKcal
        )
        applyNutritionTargets(for: userProfile!)
        observability.track("profile_calorie_delta_updated", metadata: ["delta": "\(delta)"])
        persist()
    }

    func updateDailyWorkoutGoal(_ goal: Int) {
        guard let profile = userProfile else { return }
        userProfile = UserProfile(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            preferredHeightUnit: profile.preferredHeightUnit,
            preferredWeightUnit: profile.preferredWeightUnit,
            primaryGoal: profile.primaryGoal,
            activityLevel: profile.activityLevel,
            calorieDeltaGoalKcal: profile.calorieDeltaGoalKcal,
            dailyWorkoutGoalKcal: max(80, goal)
        )
        observability.track("profile_daily_workout_goal_updated", metadata: ["goal": "\(goal)"])
        persist()
    }

    func updateProfileBasics(age: Int, sex: Sex, heightCm: Double, weightKg: Double) {
        guard let profile = userProfile else { return }
        userProfile = UserProfile(
            age: max(1, age),
            sex: sex,
            heightCm: max(80, heightCm),
            weightKg: max(25, weightKg),
            preferredHeightUnit: profile.preferredHeightUnit,
            preferredWeightUnit: profile.preferredWeightUnit,
            primaryGoal: profile.primaryGoal,
            activityLevel: profile.activityLevel,
            calorieDeltaGoalKcal: profile.calorieDeltaGoalKcal,
            dailyWorkoutGoalKcal: profile.dailyWorkoutGoalKcal
        )
        applyNutritionTargets(for: userProfile!)
        observability.track("profile_basics_updated")
        persist()
    }

    func updatePreferredUnits(heightUnit: HeightUnit, weightUnit: WeightUnit) {
        guard let profile = userProfile else { return }
        userProfile = UserProfile(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            preferredHeightUnit: heightUnit,
            preferredWeightUnit: weightUnit,
            primaryGoal: profile.primaryGoal,
            activityLevel: profile.activityLevel,
            calorieDeltaGoalKcal: profile.calorieDeltaGoalKcal,
            dailyWorkoutGoalKcal: profile.dailyWorkoutGoalKcal
        )
        observability.track("profile_units_updated", metadata: ["height": heightUnit.rawValue, "weight": weightUnit.rawValue])
        persist()
    }

    func signOut() {
        isAuthenticated = false
        observability.track("auth_sign_out")
        persist()
    }

    var aiAssistantDailyLimit: Int {
        subscriptionPlan == .pro ? 100 : 5
    }

    var aiAssistantRemainingCount: Int {
        resetAIAssistantQuotaIfNeeded()
        return max(0, aiAssistantDailyLimit - aiAssistantDailyCount)
    }

    func consumeAIAssistantQuota() -> Bool {
        resetAIAssistantQuotaIfNeeded()
        guard aiAssistantDailyCount < aiAssistantDailyLimit else { return false }
        aiAssistantDailyCount += 1
        persist()
        return true
    }

    func requestHealthAccess() async {
        let result = await healthKitManager.requestAuthorization()
        healthStatus = result.status
        latestHealthSummary = result.summary
        todayExerciseMinutes = Int((result.exerciseMinutes ?? 0).rounded())
        healthInsights = result.insights
        if let snapshot = result.snapshot {
            todayActiveEnergyKcal = Int((snapshot.activeEnergyKcal ?? 0).rounded())
            todayStepCount = Int((snapshot.stepCount ?? 0).rounded())
            todayDistanceKm = snapshot.distanceKm ?? 0
            todayHRVms = Int((snapshot.hrvMs ?? 0).rounded())
            todaySleepHours = snapshot.sleepHours ?? 0
            todayAvgHeartRate = Int((snapshot.avgHeartRate ?? 0).rounded())
            todayMinHeartRate = Int((snapshot.minHeartRate ?? 0).rounded())
            todayMaxHeartRate = Int((snapshot.maxHeartRate ?? 0).rounded())
        } else {
            todayActiveEnergyKcal = 0
            todayStepCount = 0
            todayDistanceKm = 0
            todayHRVms = 0
            todaySleepHours = 0
            todayAvgHeartRate = 0
            todayMinHeartRate = 0
            todayMaxHeartRate = 0
        }
        lastHealthReadinessScore = result.readinessScore
        recomputeDashboardReadiness()
        await refreshCoachAdvice()
        observability.track("health_access_result", metadata: ["status": result.status.rawValue])
        persist()
    }

    func addWorkout(input: WorkoutInput) {
        rolloverDayIfNeeded()
        let estimatedCalories = Self.estimateWorkoutCalories(from: input)
        workoutLogs.insert(
            WorkoutLogItem(
                id: UUID(),
                exerciseName: input.exerciseName,
                sets: input.sets,
                reps: input.reps,
                weight: input.weight,
                rpe: input.rpe,
                estimatedCalories: estimatedCalories,
                loggedAt: Date()
            ),
            at: 0
        )
        let result = recoveryCalculator.updateRecovery(
            current: recoveryItems,
            input: input,
            readinessScore: dashboard.readinessScore,
            customExerciseContributions: customExerciseContributions
        )
        let updated = result.items
        recoveryItems = updated
        lastWorkoutSummary = result.summary
        recomputeDashboardReadiness()
        if let profile = userProfile {
            applyNutritionTargets(for: profile)
        }
        refreshCoachAdvice()
        observability.track(
            "workout_added",
            metadata: [
                "exercise": input.exerciseName,
                "sets": "\(input.sets)",
                "reps": "\(input.reps)"
            ]
        )
        persist()
        maybeLearnCustomContributionsIfNeeded(for: input)
    }

    private static func normalizeExerciseKey(_ exerciseName: String) -> String {
        exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizeLearnedContributionMap(_ raw: [String: Double]) -> [String: Double] {
        // Keep only keys that correspond to our current muscle catalog.
        let lowerRaw = Dictionary(uniqueKeysWithValues: raw.map { ($0.key.lowercased(), $0.value) })
        var result: [String: Double] = [:]
        for group in MuscleCatalog.allGroups {
            let k = group.lowercased()
            if let v = lowerRaw[k] {
                result[k] = max(0, v)
            }
        }
        let sum = result.values.reduce(0, +)
        guard sum > 0 else { return result }
        return result.mapValues { $0 / sum }
    }

    private func maybeLearnCustomContributionsIfNeeded(for input: WorkoutInput) {
        guard GeminiAssistantService.isConfigured else { return }
        let exerciseKey = Self.normalizeExerciseKey(input.exerciseName)
        guard customExerciseContributions[exerciseKey] == nil else { return }
        guard RecoveryCalculator.builtInContributionMap(for: input.exerciseName) == nil else { return }
        guard !contributionLearningInProgress.contains(exerciseKey) else { return }

        contributionLearningInProgress.insert(exerciseKey)
        Task { [exerciseName = input.exerciseName, exerciseKey] in
            do {
                let gemini = GeminiAssistantService()
                let learned = try await gemini.inferMuscleContributions(exerciseName: exerciseName)
                let normalized = await MainActor.run {
                    self.normalizeLearnedContributionMap(learned)
                }

                await MainActor.run {
                    self.customExerciseContributions[exerciseKey] = normalized
                    self.contributionLearningInProgress.remove(exerciseKey)
                    self.persist()
                }
            } catch {
                _ = await MainActor.run {
                    self.contributionLearningInProgress.remove(exerciseKey)
                }
            }
        }
    }

    func deleteWorkout(id: UUID) {
        workoutLogs.removeAll { $0.id == id }
        if let profile = userProfile {
            applyNutritionTargets(for: profile)
        }
        observability.track("workout_deleted")
        persist()
    }

    func restoreWorkout(_ item: WorkoutLogItem) {
        guard !workoutLogs.contains(where: { $0.id == item.id }) else { return }
        workoutLogs.insert(item, at: 0)
        if let profile = userProfile {
            applyNutritionTargets(for: profile)
        }
        observability.track("workout_restored", metadata: ["exercise": item.exerciseName])
        persist()
    }

    func requestMealScanPreview() async -> MealScanResult? {
        guard canScanMeal() else {
            lastMealDetectionSummary = "Daily meal scan limit reached. Upgrade to Pro for unlimited scans."
            return nil
        }
        let result: MealScanResult
        if useLiveBackend {
            do {
                result = try await apiClient.scanMeal(userID: userID, mealType: "dinner")
                backendStatusMessage = "Gemini meal analysis succeeded."
                observability.track("meal_scan_remote_success")
            } catch {
                result = await mealScanner.scanMockMeal()
                backendStatusMessage = "Gemini meal analysis failed. Fallback to local mock."
                observability.error("meal_scan_remote_failed", message: error.localizedDescription)
            }
        } else {
            result = await mealScanner.scanMockMeal()
            backendStatusMessage = "Using local mock meal analysis."
            observability.track("meal_scan_local_mock")
        }
        if result.foods.isEmpty {
            lastMealDetectionSummary = "No foods detected from image."
        } else {
            let top = result.foods.prefix(3).map { "\($0.name) \($0.estimatedWeightGram)g" }.joined(separator: ", ")
            lastMealDetectionSummary = "Gemini result preview: \(top)"
        }
        observability.track("meal_scan_preview_ready", metadata: ["source": result.meal.source.rawValue])
        return result
    }

    func confirmScannedMeal(_ result: MealScanResult) {
        rolloverDayIfNeeded(referenceDate: result.meal.loggedAt)
        meals.insert(result.meal, at: 0)
        dailyMealScanCount += 1
        lastMealDetectionSummary = "Meal scan confirmed and added."
        dashboard = dashboard.withNutritionDelta(calories: result.meal.calories, protein: result.meal.protein, carbs: result.meal.carbs, fat: result.meal.fat)
        refreshCoachAdvice()
        observability.track("meal_added_scan", metadata: ["source": result.meal.source.rawValue])
        persist()
    }

    func addManualMeal(name: String, calories: Int, protein: Int, carbs: Int, fat: Int, loggedAt: Date = Date()) {
        rolloverDayIfNeeded(referenceDate: loggedAt)
        let meal = MealItem(
            id: UUID(),
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            confidence: 1.0,
            needsConfirmation: false,
            questions: [],
            loggedAt: loggedAt,
            source: .manual
        )
        meals.insert(meal, at: 0)
        lastMealDetectionSummary = "Manual meal added."
        dashboard = dashboard.withNutritionDelta(calories: calories, protein: protein, carbs: carbs, fat: fat)
        refreshCoachAdvice()
        observability.track("meal_added_manual", metadata: ["name": name, "calories": "\(calories)"])
        persist()
    }

    func nutritionSummary(for range: NutritionTimeRange, referenceDate: Date = Date()) -> NutritionSummary {
        rolloverDayIfNeeded(referenceDate: referenceDate)
        let calendar = Calendar.current
        let periodMeals = meals.filter { meal in
            switch range {
            case .day:
                return calendar.isDate(meal.loggedAt, inSameDayAs: referenceDate)
            case .week:
                return calendar.isDate(meal.loggedAt, equalTo: referenceDate, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(meal.loggedAt, equalTo: referenceDate, toGranularity: .month)
            case .year:
                return calendar.isDate(meal.loggedAt, equalTo: referenceDate, toGranularity: .year)
            }
        }
        return NutritionSummary(
            calories: periodMeals.reduce(0) { $0 + $1.calories },
            protein: periodMeals.reduce(0) { $0 + $1.protein },
            carbs: periodMeals.reduce(0) { $0 + $1.carbs },
            fat: periodMeals.reduce(0) { $0 + $1.fat },
            mealCount: periodMeals.count
        )
    }

    func meals(for range: NutritionTimeRange, referenceDate: Date = Date()) -> [MealItem] {
        rolloverDayIfNeeded(referenceDate: referenceDate)
        let calendar = Calendar.current
        return meals
            .filter { meal in
                switch range {
                case .day:
                    return calendar.isDate(meal.loggedAt, inSameDayAs: referenceDate)
                case .week:
                    return calendar.isDate(meal.loggedAt, equalTo: referenceDate, toGranularity: .weekOfYear)
                case .month:
                    return calendar.isDate(meal.loggedAt, equalTo: referenceDate, toGranularity: .month)
                case .year:
                    return calendar.isDate(meal.loggedAt, equalTo: referenceDate, toGranularity: .year)
                }
            }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    func deleteMeal(id: UUID) {
        guard let index = meals.firstIndex(where: { $0.id == id }) else { return }
        let removed = meals.remove(at: index)
        dashboard = dashboard.withNutritionDelta(
            calories: -removed.calories,
            protein: -removed.protein,
            carbs: -removed.carbs,
            fat: -removed.fat
        )
        lastMealDetectionSummary = "Meal deleted."
        refreshCoachAdvice()
        observability.track("meal_deleted")
        persist()
    }

    func restoreMeal(_ item: MealItem) {
        guard !meals.contains(where: { $0.id == item.id }) else { return }
        meals.insert(item, at: 0)
        dashboard = dashboard.withNutritionDelta(
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat
        )
        lastMealDetectionSummary = "Meal restored."
        refreshCoachAdvice()
        observability.track("meal_restored", metadata: ["name": item.name])
        persist()
    }

    func nutritionTrend(window: NutritionTrendWindow, referenceDate: Date = Date()) -> [NutritionTrendPoint] {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: referenceDate)
        var points: [NutritionTrendPoint] = []

        for dayOffset in stride(from: window.dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: endDay) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayMeals = meals.filter { $0.loggedAt >= day && $0.loggedAt < nextDay }
            points.append(
                NutritionTrendPoint(
                    date: day,
                    calories: dayMeals.reduce(0) { $0 + $1.calories },
                    protein: dayMeals.reduce(0) { $0 + $1.protein },
                    carbs: dayMeals.reduce(0) { $0 + $1.carbs },
                    fat: dayMeals.reduce(0) { $0 + $1.fat }
                )
            )
        }
        return points
    }

    func workoutTrend(window: NutritionTrendWindow, referenceDate: Date = Date()) -> [WorkoutTrendPoint] {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: referenceDate)
        var points: [WorkoutTrendPoint] = []

        for dayOffset in stride(from: window.dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: endDay) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayWorkouts = workoutLogs.filter { $0.loggedAt >= day && $0.loggedAt < nextDay }
            points.append(
                WorkoutTrendPoint(
                    date: day,
                    calories: dayWorkouts.reduce(0) { $0 + $1.estimatedCalories }
                )
            )
        }
        return points
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
                observability.track("coach_remote_success")
                return
            } catch {
                backendStatusMessage = "Live backend coach advice failed. Fallback to local engine."
                observability.error("coach_remote_failed", message: error.localizedDescription)
            }
        }
        coachAdvice = coachEngine.generate(
            context: CoachContext(
                dashboard: dashboard,
                recoveryItems: recoveryItems,
                mealsToday: meals.count,
                healthStatus: healthStatus,
                healthInsights: healthInsights,
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
        observability.track("subscription_plan_set", metadata: ["plan": plan.rawValue])
        persist()
    }

    func canScanMeal() -> Bool {
        subscriptionPlan == .pro
    }

    func remainingMealScansText() -> String {
        if subscriptionPlan == .pro {
            return "Pro: unlimited photo scans"
        }
        return "Free: manual logging only"
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
        if let preview = await requestMealScanPreview() {
            confirmScannedMeal(preview)
        }
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
        observability.track("backend_mode_changed", metadata: ["mode": enabled ? "live" : "mock"])
        persist()
    }

    func setSignalExplanationsEnabled(_ enabled: Bool) {
        showSignalExplanations = enabled
        observability.track("signal_explanations_toggled", metadata: ["enabled": enabled ? "true" : "false"])
        persist()
    }

    func setPlannedTrainingDay(weekday: Int, enabled: Bool) {
        guard (1...7).contains(weekday) else { return }
        if enabled {
            plannedTrainingWeekdays.insert(weekday)
        } else {
            plannedTrainingWeekdays.remove(weekday)
        }
        if let profile = userProfile {
            applyNutritionTargets(for: profile)
        }
        observability.track(
            "planned_training_day_updated",
            metadata: ["weekday": "\(weekday)", "enabled": enabled ? "true" : "false"]
        )
        persist()
    }

    func requestVoiceInputAccess() async {
        let result = await voicePermissionManager.requestAccess()
        voicePermissionStatus = result.status
        voicePermissionMessage = result.message
        observability.track("voice_permission_result", metadata: ["status": result.status.rawValue])
    }

    func exportLocalData() throws -> URL {
        let snapshot = PersistedState(
            dashboard: dashboard.toDTO(),
            recoveryItems: recoveryItems.map { $0.toDTO() },
            workoutLogs: workoutLogs.map { $0.toDTO() },
            meals: meals.map { $0.toDTO() },
            coachAdvice: coachAdvice.toDTO(),
            healthStatus: healthStatus.rawValue,
            latestHealthSummary: latestHealthSummary,
            healthInsights: healthInsights,
            lastWorkoutSummary: lastWorkoutSummary,
            lastMealDetectionSummary: lastMealDetectionSummary,
            subscriptionPlan: subscriptionPlan.rawValue,
            dailyMealScanCount: dailyMealScanCount,
            mealScanDailyLimit: mealScanDailyLimit,
            lastSubscriptionMessage: lastSubscriptionMessage,
            useLiveBackend: useLiveBackend,
            backendStatusMessage: backendStatusMessage,
            showSignalExplanations: showSignalExplanations,
            isAuthenticated: isAuthenticated,
            hasCompletedOnboarding: hasCompletedOnboarding,
            authMethod: authMethod,
            authIdentifier: authIdentifier,
            userProfile: userProfile,
            plannedTrainingWeekdays: Array(plannedTrainingWeekdays).sorted(),
            aiAssistantDailyCount: aiAssistantDailyCount,
            aiAssistantLastUsedDay: aiAssistantLastUsedDay
        )
        let url = try persistence.export(snapshot)
        observability.track("data_export_local_success")
        return url
    }

    func resetLocalTrackingData() {
        dashboard = Self.defaultDashboard()
        recoveryItems = Self.emptyRecoveryItems()
        workoutLogs = []
        meals = []
        coachAdvice = CoachAdvice.generate(from: dashboard, recoveryItems: recoveryItems)
        healthStatus = .notRequested
        latestHealthSummary = "Health data has not been synced yet."
        healthInsights = []
        lastWorkoutSummary = "No workouts logged yet."
        lastMealDetectionSummary = "No meal scans yet."
        dailyMealScanCount = 0

        if let profile = userProfile {
            applyNutritionTargets(for: profile)
        } else {
            refreshCoachAdvice()
        }
        observability.track("data_reset_local_tracking")
        persist()
    }

    func requestWorkoutAssistant(input: String) async throws -> (reply: String, parsed: (exercise: String, sets: String, reps: String, weight: String, rpe: String)?) {
        let decoded = try await apiClient.parseWorkoutAssistant(userID: userID, message: input)
        backendStatusMessage = "Live backend workout assistant succeeded."
        let parsed: (exercise: String, sets: String, reps: String, weight: String, rpe: String)?
        if let exercise = decoded.exercise, !exercise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parsed = (
                exercise.trimmingCharacters(in: .whitespacesAndNewlines),
                decoded.sets.map(String.init) ?? "",
                decoded.reps.map(String.init) ?? "",
                decoded.weight.map { String(Int($0.rounded())) } ?? "",
                decoded.rpe.map(String.init) ?? ""
            )
        } else {
            parsed = nil
        }
        observability.track("assistant_workout_remote_success", metadata: ["parsed": parsed == nil ? "false" : "true"])
        return (decoded.reply, parsed)
    }

    func requestMealAssistant(input: String, imageData: Data? = nil) async throws -> (reply: String, parsed: (name: String, calories: String, protein: String, carbs: String, fat: String)?) {
        let decoded = try await apiClient.parseMealAssistant(userID: userID, message: input, imageData: imageData)
        backendStatusMessage = "Live backend meal assistant succeeded."
        let parsed: (name: String, calories: String, protein: String, carbs: String, fat: String)?
        if let name = decoded.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parsed = (
                name.trimmingCharacters(in: .whitespacesAndNewlines),
                decoded.calories.map(String.init) ?? "",
                decoded.protein.map(String.init) ?? "",
                decoded.carbs.map(String.init) ?? "",
                decoded.fat.map(String.init) ?? ""
            )
        } else {
            parsed = nil
        }
        observability.track("assistant_meal_remote_success", metadata: ["parsed": parsed == nil ? "false" : "true"])
        return (decoded.reply, parsed)
    }

    func requestChatAssistant(input: String) async throws -> String {
        let decoded = try await apiClient.parseChatAssistant(userID: userID, message: input)
        backendStatusMessage = "Live backend chat assistant succeeded."
        observability.track("assistant_chat_remote_success")
        return decoded.reply
    }

    private func persist() {
        persistence.save(currentPersistedState())
    }

    private func currentPersistedState() -> PersistedState {
        PersistedState(
            dashboard: dashboard.toDTO(),
            recoveryItems: recoveryItems.map { $0.toDTO() },
            workoutLogs: workoutLogs.map { $0.toDTO() },
            meals: meals.map { $0.toDTO() },
            coachAdvice: coachAdvice.toDTO(),
            healthStatus: healthStatus.rawValue,
            latestHealthSummary: latestHealthSummary,
            healthInsights: healthInsights,
            lastWorkoutSummary: lastWorkoutSummary,
            lastMealDetectionSummary: lastMealDetectionSummary,
            subscriptionPlan: subscriptionPlan.rawValue,
            dailyMealScanCount: dailyMealScanCount,
            mealScanDailyLimit: mealScanDailyLimit,
            lastSubscriptionMessage: lastSubscriptionMessage,
            useLiveBackend: useLiveBackend,
            backendStatusMessage: backendStatusMessage,
            showSignalExplanations: showSignalExplanations,
            isAuthenticated: isAuthenticated,
            hasCompletedOnboarding: hasCompletedOnboarding,
            authMethod: authMethod,
            authIdentifier: authIdentifier,
            userProfile: userProfile,
            plannedTrainingWeekdays: Array(plannedTrainingWeekdays).sorted(),
            aiAssistantDailyCount: aiAssistantDailyCount,
            aiAssistantLastUsedDay: aiAssistantLastUsedDay,
            customExerciseContributions: customExerciseContributions.isEmpty ? nil : customExerciseContributions
        )
    }

    private func resetAIAssistantQuotaIfNeeded(referenceDate: Date = Date()) {
        let today = Self.dayKey(for: referenceDate)
        if aiAssistantLastUsedDay != today {
            aiAssistantLastUsedDay = today
            aiAssistantDailyCount = 0
        }
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func normalizedRecoveryItems(from items: [MuscleRecoveryItem]) -> [MuscleRecoveryItem] {
        var byName = Dictionary(uniqueKeysWithValues: items.map { ($0.muscleName.lowercased(), $0) })
        for group in MuscleCatalog.allGroups {
            let key = group.lowercased()
            if byName[key] == nil {
                byName[key] = MuscleRecoveryItem(
                    muscleName: group,
                    status: .ready,
                    fatigueScore: 0,
                    remainingHours: 0
                )
            }
        }
        return MuscleCatalog.allGroups.compactMap { byName[$0.lowercased()] }
    }

    private static func emptyRecoveryItems() -> [MuscleRecoveryItem] {
        MuscleCatalog.allGroups.map {
            MuscleRecoveryItem(muscleName: $0, status: .ready, fatigueScore: 0, remainingHours: 0)
        }
    }

    private static func defaultDashboard() -> TodayDashboard {
        TodayDashboard(
            readinessScore: 100,
            statusText: "Ready for training",
            trainingRecommendation: "No workout logged yet.",
            calorieGoal: 2200,
            caloriesConsumed: 0,
            proteinGoal: 150,
            proteinConsumed: 0,
            carbsGoal: 250,
            carbsConsumed: 0,
            fatGoal: 70,
            fatConsumed: 0
        )
    }

    private static func estimateWorkoutCalories(from input: WorkoutInput) -> Int {
        let volume = Double(max(1, input.sets) * max(1, input.reps))
        let intensity = Double(max(5, input.rpe)) / 10.0
        let weightFactor = max(1.0, input.weight / 30.0)
        let kcal = (volume * intensity * weightFactor) * 2.1
        return max(20, Int(kcal.rounded()))
    }

    /// Overall score = local muscle readiness + system recovery signals.
    private func recomputeDashboardReadiness() {
        let local = RecoveryCalculator.readinessScore(from: recoveryItems)
        let combined = blendedReadinessScore(
            localMuscleReadiness: local,
            systemReadiness: lastHealthReadinessScore,
            insights: healthInsights
        )
        dashboard = dashboard.withReadiness(combined)
    }

    private func blendedReadinessScore(localMuscleReadiness: Int, systemReadiness: Int?, insights: [String]) -> Int {
        let local = Double(max(0, min(100, localMuscleReadiness)))
        let base: Double
        if let systemReadiness {
            let system = Double(max(0, min(100, systemReadiness)))
            base = (local * 0.68) + (system * 0.32)
        } else {
            base = local
        }

        let isSleepDebt = insights.contains { $0.localizedCaseInsensitiveContains("Sleep Debt") }
        let isHRVDown = insights.contains { $0.localizedCaseInsensitiveContains("HRV Down") }
        let isRHRElevated = insights.contains { $0.localizedCaseInsensitiveContains("RHR Elevated") }
        let isLoadHigh = insights.contains { $0.localizedCaseInsensitiveContains("Load High") }
        let cautionCount = [isSleepDebt, isHRVDown, isRHRElevated, isLoadHigh].filter { $0 }.count

        var adjusted = base
        if cautionCount >= 2 {
            adjusted = min(adjusted, 62.0)
        } else if cautionCount == 1 {
            adjusted = min(adjusted, 76.0)
        } else {
            let isSleepReady = insights.contains { $0.localizedCaseInsensitiveContains("Sleep Ready") }
            let isHRVUp = insights.contains { $0.localizedCaseInsensitiveContains("HRV Up") }
            if isSleepReady && isHRVUp {
                adjusted += 3
            }
        }
        return max(0, min(100, Int(adjusted.rounded())))
    }

    private func applyNutritionTargets(for profile: UserProfile) {
        let targets = Self.nutritionTargets(for: profile, isTrainingDay: isTrainingDay())
        dashboard = dashboard.withNutritionGoals(
            calorieGoal: targets.calorieGoal,
            proteinGoal: targets.proteinGoal,
            carbsGoal: targets.carbsGoal,
            fatGoal: targets.fatGoal
        )
        syncTodayNutritionFromMeals()
        refreshCoachAdvice()
    }

    private func syncTodayNutritionFromMeals(referenceDate: Date = Date()) {
        let today = nutritionSummary(for: .day, referenceDate: referenceDate)
        dashboard = dashboard.withNutritionConsumed(
            calories: today.calories,
            protein: today.protein,
            carbs: today.carbs,
            fat: today.fat
        )
    }

    private func rolloverDayIfNeeded(referenceDate: Date = Date()) {
        let day = Self.dayKey(for: referenceDate)
        guard day != currentDayKey else { return }
        currentDayKey = day
        syncTodayNutritionFromMeals(referenceDate: referenceDate)
        todayExerciseMinutes = 0
        todayActiveEnergyKcal = 0
        todayStepCount = 0
        todayDistanceKm = 0
        todayHRVms = 0
        todaySleepHours = 0
        todayAvgHeartRate = 0
        todayMinHeartRate = 0
        todayMaxHeartRate = 0
    }

    private func setupDayChangedObserver() {
        dayChangedObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rolloverDayIfNeeded()
            self?.persist()
        }
    }

    static func nutritionTargets(for profile: UserProfile, isTrainingDay: Bool) -> (calorieGoal: Int, proteinGoal: Int, carbsGoal: Int, fatGoal: Int, recommendation: String) {
        let maintenance = profile.bmr * profile.activityLevel.multiplier
        let delta = Double(profile.calorieDeltaGoalKcal)
        let targetCalories = max(1200, Int((maintenance + delta).rounded()))

        let proteinPerKg = profile.primaryGoal == .muscleGain ? 2.0 : 2.2
        let fatPerKg = profile.primaryGoal == .muscleGain ? 0.9 : 0.8
        let proteinGoal = max(80, Int((profile.weightKg * proteinPerKg).rounded()))
        let fatGoal = max(35, Int((profile.weightKg * fatPerKg).rounded()))
        let carbCalories = max(0, targetCalories - (proteinGoal * 4) - (fatGoal * 9))
        let carbsGoal = max(60, Int((Double(carbCalories) / 4.0).rounded()))
        let recommendation = "Custom calorie delta: \(profile.calorieDeltaGoalKcal >= 0 ? "+" : "")\(profile.calorieDeltaGoalKcal) kcal/day."
        return (targetCalories, proteinGoal, carbsGoal, fatGoal, recommendation)
    }

    private func isTrainingDay(referenceDate: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let hasWorkoutLogged = workoutLogs.contains { calendar.isDate($0.loggedAt, inSameDayAs: referenceDate) }
        let weekday = calendar.component(.weekday, from: referenceDate)
        let isPlannedTrainingWeekday = plannedTrainingWeekdays.contains(weekday)
        return hasWorkoutLogged || isPlannedTrainingWeekday
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

private extension WorkoutLogItem {
    func toDTO() -> WorkoutLogDTO {
        WorkoutLogDTO(
            id: id.uuidString,
            exerciseName: exerciseName,
            sets: sets,
            reps: reps,
            weight: weight,
            rpe: rpe,
            estimatedCalories: estimatedCalories,
            loggedAt: loggedAt
        )
    }
}

private extension WorkoutLogDTO {
    func toDomain() -> WorkoutLogItem {
        WorkoutLogItem(
            id: UUID(uuidString: id) ?? UUID(),
            exerciseName: exerciseName,
            sets: sets,
            reps: reps,
            weight: weight,
            rpe: rpe,
            estimatedCalories: estimatedCalories,
            loggedAt: loggedAt
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
            id: id.uuidString,
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            confidence: confidence,
            needsConfirmation: needsConfirmation,
            questions: questions,
            loggedAt: loggedAt,
            source: source.rawValue
        )
    }
}

private extension MealDTO {
    func toDomain() -> MealItem {
        MealItem(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            confidence: confidence,
            needsConfirmation: needsConfirmation,
            questions: questions,
            loggedAt: loggedAt,
            source: MealSource(rawValue: source) ?? .manual
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
