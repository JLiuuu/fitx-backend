//
//  fitnesscoachTests.swift
//  fitnesscoachTests
//
//  Created by Jeremy Liu on 4/27/26.
//

import Testing
@testable import fitnesscoach

struct fitnesscoachTests {

    @Test func recoveryCalculatorIncreasesTargetMuscleFatigue() async throws {
        let calculator = RecoveryCalculator()
        let current = [
            MuscleRecoveryItem(muscleName: "Chest", status: .ready, fatigueScore: 20, remainingHours: 0),
            MuscleRecoveryItem(muscleName: "Lats", status: .ready, fatigueScore: 20, remainingHours: 0)
        ]
        let result = calculator.updateRecovery(
            current: current,
            input: WorkoutInput(exerciseName: "Bench Press", sets: 4, reps: 8, weight: 80, rpe: 8)
        )

        let chestFatigue = result.items.first(where: { $0.muscleName == "Chest" })?.fatigueScore ?? 0
        let latsFatigue = result.items.first(where: { $0.muscleName == "Lats" })?.fatigueScore ?? 0

        #expect(chestFatigue > latsFatigue)
    }

    @Test func coachEngineIncludesPlanNotice() async throws {
        let engine = CoachEngine()
        let context = CoachContext(
            dashboard: MockData.dashboard,
            recoveryItems: MockData.recoveryItems,
            mealsToday: 2,
            healthStatus: .notRequested,
            healthInsights: [],
            subscriptionPlan: .free
        )
        let advice = engine.generate(context: context)

        #expect(advice.warning.contains("Free plan"))
    }

    @Test func rowTargetsBackAndBiceps() async throws {
        let calculator = RecoveryCalculator()
        let current = [
            MuscleRecoveryItem(muscleName: "Lats", status: .ready, fatigueScore: 20, remainingHours: 0),
            MuscleRecoveryItem(muscleName: "Upper Back (Traps)", status: .ready, fatigueScore: 20, remainingHours: 0),
            MuscleRecoveryItem(muscleName: "Biceps", status: .ready, fatigueScore: 20, remainingHours: 0),
            MuscleRecoveryItem(muscleName: "Chest", status: .ready, fatigueScore: 20, remainingHours: 0)
        ]
        let result = calculator.updateRecovery(
            current: current,
            input: WorkoutInput(exerciseName: "Seated Cable Row", sets: 4, reps: 10, weight: 60, rpe: 8),
            readinessScore: 70
        )

        let lats = result.items.first(where: { $0.muscleName == "Lats" })?.fatigueScore ?? 0
        let upperBack = result.items.first(where: { $0.muscleName == "Upper Back (Traps)" })?.fatigueScore ?? 0
        let biceps = result.items.first(where: { $0.muscleName == "Biceps" })?.fatigueScore ?? 0
        let chest = result.items.first(where: { $0.muscleName == "Chest" })?.fatigueScore ?? 0

        #expect(lats > chest)
        #expect(upperBack > chest)
        #expect(biceps > chest)
    }

    @Test func persistenceRoundTrip() async throws {
        let service = PersistenceService(filename: "test_state.json")
        let state = PersistedState(
            dashboard: DashboardDTO(
                readinessScore: 80,
                statusText: "Ready",
                trainingRecommendation: "Pull",
                calorieGoal: 2200,
                caloriesConsumed: 1200,
                proteinGoal: 180,
                proteinConsumed: 110,
                carbsGoal: 250,
                carbsConsumed: 130,
                fatGoal: 70,
                fatConsumed: 40
            ),
            recoveryItems: [],
            workoutLogs: [],
            meals: [],
            coachAdvice: CoachAdviceDTO(
                readinessScore: 80,
                training: "t",
                nutrition: "n",
                recovery: "r",
                warning: "w",
                missingData: "m"
            ),
            healthStatus: HealthAuthorizationStatus.notRequested.rawValue,
            latestHealthSummary: "none",
            healthInsights: [],
            lastWorkoutSummary: "none",
            lastMealDetectionSummary: "none",
            subscriptionPlan: SubscriptionPlan.free.rawValue,
            dailyMealScanCount: 0,
            mealScanDailyLimit: 1,
            lastSubscriptionMessage: "free",
            useLiveBackend: false,
            backendStatusMessage: "mock",
            showSignalExplanations: true
        )
        service.save(state)
        let loaded = service.load()

        #expect(loaded?.dashboard.readinessScore == 80)
        #expect(loaded?.subscriptionPlan == SubscriptionPlan.free.rawValue)
    }

    @Test func workoutParserSupportsCompactAndSymbolFormats() async throws {
        let parsed = await MainActor.run { () -> (exercise: String, sets: String, reps: String, weight: String, rpe: String)? in
            let vm = WorkoutViewModel(appState: AppState())
            return vm.parseWorkoutInput("bench press 4x8 @80 rpe8")
        }

        #expect(parsed != nil)
        #expect(parsed?.sets == "4")
        #expect(parsed?.reps == "8")
        #expect(parsed?.weight == "80")
        #expect(parsed?.rpe == "8")
    }

    @Test func mealParserSupportsMacroShorthandFormats() async throws {
        let parsed = await MainActor.run { () -> (name: String, calories: String, protein: String, carbs: String, fat: String)? in
            let vm = NutritionViewModel(appState: AppState())
            return vm.parseMealInput("chicken rice kcal 620 p45 c70 f15")
        }

        #expect(parsed != nil)
        #expect(parsed?.calories == "620")
        #expect(parsed?.protein == "45")
        #expect(parsed?.carbs == "70")
        #expect(parsed?.fat == "15")
    }

}
