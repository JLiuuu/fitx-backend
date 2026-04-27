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
            subscriptionPlan: .free
        )
        let advice = engine.generate(context: context)

        #expect(advice.warning.contains("Free plan"))
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
            lastWorkoutSummary: "none",
            lastMealDetectionSummary: "none",
            subscriptionPlan: SubscriptionPlan.free.rawValue,
            dailyMealScanCount: 0,
            mealScanDailyLimit: 1,
            lastSubscriptionMessage: "free",
            useLiveBackend: false,
            backendStatusMessage: "mock"
        )
        service.save(state)
        let loaded = service.load()

        #expect(loaded?.dashboard.readinessScore == 80)
        #expect(loaded?.subscriptionPlan == SubscriptionPlan.free.rawValue)
    }

}
