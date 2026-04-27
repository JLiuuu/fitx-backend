import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

struct RecoveryCalculator {
    func updateRecovery(current: [MuscleRecoveryItem], input: WorkoutInput) -> [MuscleRecoveryItem] {
        let load = Double(input.sets * input.reps) * input.weight
        let intensityFactor = Double(max(5, input.rpe)) / 10.0
        let fatigueDelta = Int((load / 120.0) * intensityFactor)

        return current.map { item in
            let matched = input.exerciseName.lowercased().contains(item.muscleName.lowercased())
            let nextFatigue: Int
            if matched {
                nextFatigue = min(100, item.fatigueScore + max(8, fatigueDelta))
            } else {
                nextFatigue = max(0, item.fatigueScore - 2)
            }

            let status: RecoveryStatus
            switch nextFatigue {
            case 70...:
                status = .fatigued
            case 40..<70:
                status = .recovering
            default:
                status = .ready
            }
            let remainingHours = max(0, nextFatigue / 3)

            return MuscleRecoveryItem(
                muscleName: item.muscleName,
                status: status,
                fatigueScore: nextFatigue,
                remainingHours: remainingHours
            )
        }
    }

    static func readinessScore(from items: [MuscleRecoveryItem]) -> Int {
        guard !items.isEmpty else { return 70 }
        let avgFatigue = items.map(\.fatigueScore).reduce(0, +) / items.count
        return max(0, min(100, 100 - avgFatigue))
    }
}

final class HealthKitManager {
    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    func requestAuthorization() async -> HealthSyncResult {
        #if canImport(HealthKit)
        var readTypes: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let value = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(value)
        }
        if let value = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            readTypes.insert(value)
        }
        if let value = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(value)
        }
        if let value = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(value)
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return HealthSyncResult(
                status: .authorized,
                summary: "Health permission granted. Sample sync: HRV trend ready, sleep trend ready."
            )
        } catch {
            return HealthSyncResult(status: .denied, summary: "Authorization failed: \(error.localizedDescription)")
        }
        #else
        return HealthSyncResult(
            status: .unavailable,
            summary: "HealthKit is unavailable on current target. Using mock fitness signals."
        )
        #endif
    }
}

final class MealScannerService {
    func scanMockMeal() async -> MealScanResult {
        try? await Task.sleep(nanoseconds: 400_000_000)
        return MealScanResult(
            meal: MealItem(
                name: "Salmon Bowl (AI Scan Mock)",
                calories: 540,
                protein: 38,
                carbs: 52,
                fat: 18
            )
        )
    }
}
