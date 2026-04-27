import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

struct RecoveryCalculator {
    func updateRecovery(current: [MuscleRecoveryItem], input: WorkoutInput) -> RecoveryUpdateResult {
        let load = Double(input.sets * input.reps) * input.weight
        let intensityFactor = Double(max(5, input.rpe)) / 10.0
        let baseDelta = Int((load / 120.0) * intensityFactor)
        let muscleWeights = contributionMap(for: input.exerciseName)

        let updated = current.map { item in
            let weight = muscleWeights[item.muscleName.lowercased()] ?? 0.0
            let nextFatigue: Int
            if weight > 0 {
                nextFatigue = min(100, item.fatigueScore + max(6, Int(Double(baseDelta) * weight)))
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
        let impacted = updated.filter { $0.fatigueScore >= 40 }.map(\.muscleName).joined(separator: ", ")
        let summary = impacted.isEmpty
            ? "Workout logged. No major fatigue spike detected."
            : "Workout logged. High impact muscles: \(impacted)."
        return RecoveryUpdateResult(items: updated, summary: summary)
    }

    static func readinessScore(from items: [MuscleRecoveryItem]) -> Int {
        guard !items.isEmpty else { return 70 }
        let avgFatigue = items.map(\.fatigueScore).reduce(0, +) / items.count
        return max(0, min(100, 100 - avgFatigue))
    }

    private func contributionMap(for exercise: String) -> [String: Double] {
        let lower = exercise.lowercased()
        if lower.contains("bench") || lower.contains("chest") {
            return ["chest": 0.6, "shoulders": 0.2, "triceps": 0.2]
        }
        if lower.contains("squat") {
            return ["quads": 0.45, "glutes": 0.3, "hamstrings": 0.15]
        }
        if lower.contains("deadlift") {
            return ["hamstrings": 0.3, "glutes": 0.3, "upper back": 0.2]
        }
        if lower.contains("pull") || lower.contains("row") {
            return ["lats": 0.5, "biceps": 0.25, "upper back": 0.25]
        }
        return [lower: 0.4]
    }
}

struct RecoveryUpdateResult {
    let items: [MuscleRecoveryItem]
    let summary: String
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
