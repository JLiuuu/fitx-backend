import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(os)
import os
#endif
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Speech)
import Speech
#endif

struct RecoveryCalculator {
    func updateRecovery(
        current: [MuscleRecoveryItem],
        input: WorkoutInput,
        readinessScore: Int = 70,
        customExerciseContributions: [String: [String: Double]] = [:]
    ) -> RecoveryUpdateResult {
        let load = Double(input.sets * input.reps) * input.weight
        let intensityFactor = Double(max(5, input.rpe)) / 10.0
        let baseDelta = Int((load / 120.0) * intensityFactor)
        let recoveryMultiplier = recoverySpeedMultiplier(for: readinessScore)
        let loadMultiplier = fatigueLoadMultiplier(for: readinessScore)

        let exerciseKey = Self.normalizeExerciseKey(input.exerciseName)
        let muscleWeights: [String: Double]
        if let custom = customExerciseContributions[exerciseKey] {
            muscleWeights = custom
        } else if let builtIn = Self.builtInContributionMap(for: input.exerciseName) {
            muscleWeights = builtIn
        } else {
            muscleWeights = Self.wholeBodyFallbackContributionMap
        }

        let updated = current.map { item in
            let weight = muscleWeights[item.muscleName.lowercased()] ?? 0.0
            let nextFatigue: Int
            if weight > 0 {
                let gain = max(6, Int((Double(baseDelta) * weight * loadMultiplier).rounded()))
                nextFatigue = min(100, item.fatigueScore + gain)
            } else {
                let baseRecovery = baseRecoveryPerTick(for: item.muscleName)
                let dynamicRecovery = max(1, Int((baseRecovery * recoveryMultiplier).rounded()))
                nextFatigue = max(0, item.fatigueScore - dynamicRecovery)
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

    private func recoverySpeedMultiplier(for readinessScore: Int) -> Double {
        switch readinessScore {
        case 80...:
            return 1.2
        case 65..<80:
            return 1.0
        case 50..<65:
            return 0.9
        case 35..<50:
            return 0.8
        default:
            return 0.7
        }
    }

    private func fatigueLoadMultiplier(for readinessScore: Int) -> Double {
        switch readinessScore {
        case 80...:
            return 0.95
        case 65..<80:
            return 1.0
        case 50..<65:
            return 1.08
        case 35..<50:
            return 1.16
        default:
            return 1.25
        }
    }

    private func baseRecoveryPerTick(for muscleName: String) -> Double {
        switch muscleName.lowercased() {
        case "biceps", "triceps":
            return 3.0
        case "shoulders (front/mid)", "abs":
            return 2.6
        case "chest", "lats", "upper back (traps)", "lower back":
            return 2.3
        case "quads", "glutes", "hamstrings":
            return 2.0
        default:
            return 2.2
        }
    }

    static func readinessScore(from items: [MuscleRecoveryItem]) -> Int {
        guard !items.isEmpty else { return 70 }
        let avgFatigue = items.map(\.fatigueScore).reduce(0, +) / items.count
        return max(0, min(100, 100 - avgFatigue))
    }

    private static func normalizeExerciseKey(_ exercise: String) -> String {
        exercise.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func builtInContributionMap(for exercise: String) -> [String: Double]? {
        let lower = exercise.lowercased()

        // Push / chest
        if lower.contains("incline bench") || lower.contains("incline press") {
            return ["chest": 0.45, "shoulders (front/mid)": 0.30, "triceps": 0.25]
        }
        if lower.contains("bench") || lower.contains("chest press") {
            return ["chest": 0.55, "triceps": 0.25, "shoulders (front/mid)": 0.20]
        }
        if lower.contains("push up") || lower.contains("push-up") || lower.contains("pushup") {
            return ["chest": 0.45, "triceps": 0.30, "shoulders (front/mid)": 0.20, "abs": 0.05]
        }
        if lower.contains("fly") || lower.contains("pec deck") || lower.contains("cable crossover") {
            return ["chest": 0.75, "shoulders (front/mid)": 0.15, "triceps": 0.10]
        }
        if lower.contains("dip") {
            return ["triceps": 0.45, "chest": 0.35, "shoulders (front/mid)": 0.20]
        }

        // Shoulders
        if lower.contains("overhead press") || lower.contains("shoulder press") || lower.contains("military press") || lower == "ohp" || lower.contains(" ohp") {
            return ["shoulders (front/mid)": 0.55, "triceps": 0.25, "upper back (traps)": 0.20]
        }
        if lower.contains("lateral raise") || lower.contains("side raise") {
            return ["shoulders (front/mid)": 0.80, "upper back (traps)": 0.20]
        }
        if lower.contains("front raise") {
            return ["shoulders (front/mid)": 0.80, "chest": 0.10, "upper back (traps)": 0.10]
        }
        if lower.contains("rear delt") || lower.contains("reverse fly") || lower.contains("face pull") {
            return ["upper back (traps)": 0.55, "lower back": 0.20, "biceps": 0.15, "triceps": 0.10]
        }

        // Pull / back
        if lower.contains("pull up") || lower.contains("pull-up") || lower.contains("chin up") || lower.contains("chin-up") {
            return ["lats": 0.45, "biceps": 0.25, "upper back (traps)": 0.20, "triceps": 0.10]
        }
        if lower.contains("lat pulldown") || lower.contains("pulldown") {
            return ["lats": 0.50, "biceps": 0.20, "upper back (traps)": 0.20, "lower back": 0.10]
        }
        if lower.contains("row") {
            return ["lats": 0.35, "upper back (traps)": 0.30, "biceps": 0.20, "lower back": 0.15]
        }
        if lower.contains("shrug") {
            return ["upper back (traps)": 0.80, "biceps": 0.10, "lower back": 0.10]
        }

        // Arms
        if lower.contains("curl") {
            return ["biceps": 0.70, "triceps": 0.05, "shoulders (front/mid)": 0.10, "lower back": 0.05, "upper back (traps)": 0.10]
        }
        if lower.contains("skull crusher") || lower.contains("tricep") || lower.contains("triceps") || lower.contains("pushdown") || lower.contains("push-down") || lower.contains("extension") {
            return ["triceps": 0.75, "chest": 0.10, "shoulders (front/mid)": 0.15]
        }

        // Legs
        if lower.contains("back squat") || lower.contains("front squat") || lower == "squat" || lower.contains("hack squat") {
            return ["quads": 0.50, "glutes": 0.22, "hamstrings": 0.13, "upper back (traps)": 0.10, "lower back": 0.05]
        }
        if lower.contains("leg press") {
            return ["quads": 0.60, "glutes": 0.18, "hamstrings": 0.07, "abs": 0.05, "upper back (traps)": 0.10]
        }
        if lower.contains("split squat") || lower.contains("bulgarian") || lower.contains("lunge") || lower.contains("step up") {
            return ["quads": 0.45, "glutes": 0.22, "hamstrings": 0.13, "abs": 0.10, "upper back (traps)": 0.10]
        }
        if lower.contains("rdl") || lower.contains("romanian deadlift") {
            return ["hamstrings": 0.35, "glutes": 0.20, "upper back (traps)": 0.20, "lats": 0.15, "quads": 0.05, "lower back": 0.05]
        }
        if lower.contains("deadlift") {
            return ["hamstrings": 0.25, "glutes": 0.20, "upper back (traps)": 0.20, "lats": 0.15, "quads": 0.10, "abs": 0.05, "lower back": 0.05]
        }
        if lower.contains("hip thrust") || lower.contains("glute bridge") {
            return ["glutes": 0.60, "hamstrings": 0.10, "quads": 0.10, "upper back (traps)": 0.10, "abs": 0.10]
        }
        if lower.contains("leg curl") || lower.contains("hamstring curl") {
            return ["hamstrings": 0.85, "glutes": 0.05, "quads": 0.05, "abs": 0.05]
        }
        if lower.contains("leg extension") {
            return ["quads": 0.90, "glutes": 0.05, "hamstrings": 0.05]
        }
        if lower.contains("calf raise") || lower.contains("seated calf") || lower.contains("standing calf") {
            return ["hamstrings": 0.35, "glutes": 0.20, "quads": 0.20, "abs": 0.10, "upper back (traps)": 0.10, "lower back": 0.05]
        }

        // Core
        if lower.contains("crunch") || lower.contains("sit up") || lower.contains("sit-up") {
            return ["abs": 0.85, "upper back (traps)": 0.05, "quads": 0.10]
        }
        if lower.contains("plank") {
            return ["abs": 0.60, "chest": 0.10, "shoulders (front/mid)": 0.15, "quads": 0.05, "upper back (traps)": 0.10]
        }
        if lower.contains("russian twist") || lower.contains("twist") || lower.contains("side bend") {
            return ["abs": 0.70, "upper back (traps)": 0.10, "quads": 0.10, "shoulders (front/mid)": 0.10]
        }
        if lower.contains("ab wheel") || lower.contains("rollout") {
            return ["abs": 0.65, "chest": 0.05, "shoulders (front/mid)": 0.15, "lats": 0.15]
        }

        return nil
    }

    private static let wholeBodyFallbackContributionMap: [String: Double] = [
        "chest": 0.10,
        "shoulders (front/mid)": 0.10,
        "lower back": 0.08,
        "triceps": 0.10,
        "biceps": 0.10,
        "lats": 0.12,
        "upper back (traps)": 0.12,
        "abs": 0.08,
        "quads": 0.10,
        "glutes": 0.06,
        "hamstrings": 0.04
    ]
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
        if let value = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            readTypes.insert(value)
        }
        if let value = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(value)
        }
        if let value = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            readTypes.insert(value)
        }
        if let value = HKObjectType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(value)
        }
        if let value = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(value)
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            let snapshot = try await fetchRecoverySnapshot()
            let insights = buildInsights(from: snapshot)
            let exerciseText = snapshot.exerciseMinutes.map { "\(Int($0.rounded())) min" } ?? "--"
            let summary = "Recovery \(snapshot.recoveryScore) • HRV \(snapshot.todayHRVText) • RHR \(snapshot.todayRHRText) • Sleep \(snapshot.sleepHoursText) • Exercise \(exerciseText) • Steps \(snapshot.stepsText)"
            return HealthSyncResult(
                status: .authorized,
                summary: summary,
                readinessScore: snapshot.recoveryScore,
                insights: insights,
                exerciseMinutes: snapshot.exerciseMinutes
            )
        } catch {
            return HealthSyncResult(status: .denied, summary: "Authorization failed: \(error.localizedDescription)", readinessScore: nil, insights: [], exerciseMinutes: nil)
        }
        #else
        return HealthSyncResult(
            status: .unavailable,
            summary: "HealthKit is unavailable on current target. Using mock fitness signals.",
            readinessScore: nil,
            insights: [],
            exerciseMinutes: nil
        )
        #endif
    }

    #if canImport(HealthKit)
    private struct RecoverySnapshot {
        let recoveryScore: Int
        let todayHRV: Double?
        let baselineHRV: Double?
        let todayRHR: Double?
        let baselineRHR: Double?
        let sleepHours: Double?
        let activeEnergyKcal: Double?
        let exerciseMinutes: Double?
        let stepCount: Double?

        var todayHRVText: String { todayHRV.map { "\(Int($0)) ms" } ?? "--" }
        var todayRHRText: String { todayRHR.map { "\(Int($0)) bpm" } ?? "--" }
        var sleepHoursText: String { sleepHours.map { String(format: "%.1f h", $0) } ?? "--" }
        var stepsText: String { stepCount.map { "\(Int($0))" } ?? "--" }
    }

    private func fetchRecoverySnapshot() async throws -> RecoverySnapshot {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let start7d = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
        let start28d = calendar.date(byAdding: .day, value: -28, to: startOfToday) ?? startOfToday

        async let todayHRV = averageQuantity(identifier: .heartRateVariabilitySDNN, from: startOfToday, to: now, unit: HKUnit.secondUnit(with: .milli))
        async let baselineHRV = averageQuantity(identifier: .heartRateVariabilitySDNN, from: start7d, to: startOfToday, unit: HKUnit.secondUnit(with: .milli))
        async let todayRHR = latestQuantity(identifier: .restingHeartRate, from: start7d, to: now, unit: HKUnit.count().unitDivided(by: .minute()))
        async let baselineRHR = averageQuantity(identifier: .restingHeartRate, from: start28d, to: startOfYesterday, unit: HKUnit.count().unitDivided(by: .minute()))
        async let sleepHours = totalSleepHours(from: startOfYesterday, to: now)
        async let activeEnergy = cumulativeQuantity(identifier: .activeEnergyBurned, from: startOfToday, to: now, unit: .kilocalorie())
        async let exerciseMinutes = cumulativeQuantity(identifier: .appleExerciseTime, from: startOfToday, to: now, unit: .minute())
        async let stepCount = cumulativeQuantity(identifier: .stepCount, from: startOfToday, to: now, unit: .count())

        let raw = RecoverySnapshot(
            recoveryScore: 70,
            todayHRV: try await todayHRV,
            baselineHRV: try await baselineHRV,
            todayRHR: try await todayRHR,
            baselineRHR: try await baselineRHR,
            sleepHours: try await sleepHours,
            activeEnergyKcal: try await activeEnergy,
            exerciseMinutes: try await exerciseMinutes,
            stepCount: try await stepCount
        )
        let score = computeRecoveryScore(from: raw)
        return RecoverySnapshot(
            recoveryScore: score,
            todayHRV: raw.todayHRV,
            baselineHRV: raw.baselineHRV,
            todayRHR: raw.todayRHR,
            baselineRHR: raw.baselineRHR,
            sleepHours: raw.sleepHours,
            activeEnergyKcal: raw.activeEnergyKcal,
            exerciseMinutes: raw.exerciseMinutes,
            stepCount: raw.stepCount
        )
    }

    private func computeRecoveryScore(from snapshot: RecoverySnapshot) -> Int {
        var score = 70.0

        if let sleep = snapshot.sleepHours {
            switch sleep {
            case ..<5.5: score -= 20
            case ..<6.5: score -= 12
            case 6.5..<7.5: score -= 4
            case 7.5...9.0: score += 8
            default: score += 3
            }
        }

        if let today = snapshot.todayHRV, let baseline = snapshot.baselineHRV, baseline > 1 {
            score += ((today - baseline) / baseline) * 35
        }

        if let today = snapshot.todayRHR, let baseline = snapshot.baselineRHR, baseline > 1 {
            score -= (today - baseline) * 2.2
        }

        if let kcal = snapshot.activeEnergyKcal {
            if kcal > 1200 { score -= 12 }
            else if kcal > 850 { score -= 8 }
            else if kcal > 600 { score -= 4 }
        }

        if let mins = snapshot.exerciseMinutes, mins > 120 {
            score -= 5
        }

        if let steps = snapshot.stepCount, steps > 8000, (snapshot.activeEnergyKcal ?? 0) < 400 {
            score += 2
        }

        return Int(max(0, min(100, score.rounded())))
    }

    private func buildInsights(from snapshot: RecoverySnapshot) -> [String] {
        var labels: [String] = []

        if let sleep = snapshot.sleepHours {
            if sleep < 6.5 { labels.append("Sleep Debt: prioritize 7.5h+ tonight") }
            else if sleep >= 7.5 { labels.append("Sleep Ready: sleep support is strong") }
        } else {
            labels.append("Sleep Missing: no recent sleep data")
        }

        if let today = snapshot.todayHRV, let baseline = snapshot.baselineHRV, baseline > 1 {
            let ratio = (today - baseline) / baseline
            if ratio < -0.12 { labels.append("HRV Down: reduce intensity today") }
            else if ratio > 0.10 { labels.append("HRV Up: recovery capacity looks good") }
            else { labels.append("HRV Stable: normal autonomic load") }
        } else {
            labels.append("HRV Missing: check watch wear and sync")
        }

        if let today = snapshot.todayRHR, let baseline = snapshot.baselineRHR, baseline > 1 {
            let delta = today - baseline
            if delta > 5 { labels.append("RHR Elevated: keep training conservative") }
            else if delta < -3 { labels.append("RHR Low: good recovery sign") }
            else { labels.append("RHR Stable: baseline range") }
        } else {
            labels.append("RHR Missing: no resting HR trend yet")
        }

        if let active = snapshot.activeEnergyKcal, let minutes = snapshot.exerciseMinutes {
            if active > 900 || minutes > 110 {
                labels.append("Load High: favor lighter volume")
            } else if active < 350 && minutes < 30 {
                labels.append("Load Low: room for training stimulus")
            } else {
                labels.append("Load Balanced: current volume acceptable")
            }
        }

        return Array(labels.prefix(4))
    }

    private func quantityType(_ id: HKQuantityTypeIdentifier) throws -> HKQuantityType {
        if let value = HKObjectType.quantityType(forIdentifier: id) {
            return value
        }
        throw NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported quantity type \(id.rawValue)"])
    }

    private func categoryType(_ id: HKCategoryTypeIdentifier) throws -> HKCategoryType {
        if let value = HKObjectType.categoryType(forIdentifier: id) {
            return value
        }
        throw NSError(domain: "HealthKitManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unsupported category type \(id.rawValue)"])
    }

    private func averageQuantity(identifier: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async throws -> Double? {
        let type = try quantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func cumulativeQuantity(identifier: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async throws -> Double? {
        let type = try quantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func latestQuantity(identifier: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async throws -> Double? {
        let type = try quantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func totalSleepHours(from start: Date, to end: Date) async throws -> Double? {
        let type = try categoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]
                let seconds = sleepSamples.reduce(0.0) { partial, sample in
                    asleepValues.contains(sample.value) ? partial + sample.endDate.timeIntervalSince(sample.startDate) : partial
                }
                continuation.resume(returning: seconds / 3600.0)
            }
            store.execute(query)
        }
    }
    #endif
}

final class MealScannerService {
    func scanMockMeal() async -> MealScanResult {
        try? await Task.sleep(nanoseconds: 400_000_000)
        return MealScanResult(
            meal: MealItem(
                id: UUID(),
                name: "Salmon Bowl (AI Scan Mock)",
                calories: 540,
                protein: 38,
                carbs: 52,
                fat: 18,
                confidence: 0.81,
                needsConfirmation: true,
                questions: [
                    "Was extra oil used in the salmon?",
                    "Is this a small, medium, or large rice portion?"
                ],
                loggedAt: Date(),
                source: .aiScan
            ),
            foods: [
                DetectedFood(name: "salmon", estimatedWeightGram: 160, confidence: 0.86),
                DetectedFood(name: "white rice", estimatedWeightGram: 180, confidence: 0.77),
                DetectedFood(name: "broccoli", estimatedWeightGram: 75, confidence: 0.83)
            ]
        )
    }
}

final class ObservabilityService {
    #if canImport(os)
    private let logger = Logger(subsystem: "com.fitnesscoach.app", category: "telemetry")
    #endif

    func track(_ event: String, metadata: [String: String] = [:]) {
        let fields = metadata
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fields.isEmpty ? event : "\(event) \(fields)"
        #if canImport(os)
        logger.info("\(line, privacy: .public)")
        #else
        print("[analytics] \(line)")
        #endif
    }

    func error(_ event: String, message: String, metadata: [String: String] = [:]) {
        var merged = metadata
        merged["error"] = message
        let fields = merged
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fields.isEmpty ? event : "\(event) \(fields)"
        #if canImport(os)
        logger.error("\(line, privacy: .public)")
        #else
        print("[error] \(line)")
        #endif
    }
}

enum SocialOAuthProvider: String {
    case google
    case facebook
}

enum UnifiedAssistantIntent: String {
    case workout
    case nutrition
    case chat
}

struct UnifiedAssistantOutput {
    let reply: String
    let intent: UnifiedAssistantIntent
    let workout: (exercise: String, sets: Int, reps: Int, weight: Double, rpe: Int)?
    let meal: (name: String, calories: Int, protein: Int, carbs: Int, fat: Int)?
}

enum SocialOAuthError: LocalizedError {
    case missingClientID(provider: SocialOAuthProvider)
    case invalidRedirectURI
    case authorizationCancelled
    case missingAuthorizationCode

    var errorDescription: String? {
        switch self {
        case .missingClientID(let provider):
            return "Missing \(provider.rawValue.capitalized) OAuth client ID in environment variables."
        case .invalidRedirectURI:
            return "Invalid OAuth redirect URI configuration."
        case .authorizationCancelled:
            return "Authorization was cancelled."
        case .missingAuthorizationCode:
            return "Authorization completed without a code."
        }
    }
}

final class SocialOAuthService: NSObject {
    #if canImport(AuthenticationServices)
    private var currentSession: ASWebAuthenticationSession?
    #endif

    func authorize(provider: SocialOAuthProvider) async throws -> String {
        #if canImport(AuthenticationServices)
        let redirectURI = ProcessInfo.processInfo.environment["FITNESS_OAUTH_REDIRECT_URI"] ?? "fitnesscoach://oauth/callback"
        guard let redirectURL = URL(string: redirectURI), let callbackScheme = redirectURL.scheme else {
            throw SocialOAuthError.invalidRedirectURI
        }

        let pkce = Self.generatePKCE()
        let authorizeURL = try buildAuthorizeURL(
            provider: provider,
            redirectURI: redirectURI,
            codeChallenge: pkce.codeChallenge
        )
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizeURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.currentSession = nil
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: SocialOAuthError.authorizationCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?
                        .first(where: { $0.name == "code" })?
                        .value,
                      !code.isEmpty else {
                    continuation.resume(throwing: SocialOAuthError.missingAuthorizationCode)
                    return
                }
                continuation.resume(returning: code)
            }
            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            self.currentSession = session
            _ = session.start()
        }
        #else
        throw SocialOAuthError.authorizationCancelled
        #endif
    }

    private func buildAuthorizeURL(provider: SocialOAuthProvider, redirectURI: String, codeChallenge: String) throws -> URL {
        let clientIDEnvKey = provider == .google ? "GOOGLE_CLIENT_ID" : "FACEBOOK_APP_ID"
        guard let clientID = ProcessInfo.processInfo.environment[clientIDEnvKey], !clientID.isEmpty else {
            throw SocialOAuthError.missingClientID(provider: provider)
        }

        let state = UUID().uuidString
        var components: URLComponents
        switch provider {
        case .google:
            components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: "openid email profile"),
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "prompt", value: "select_account")
            ]
        case .facebook:
            components = URLComponents(string: "https://www.facebook.com/v20.0/dialog/oauth")!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: "email,public_profile"),
                URLQueryItem(name: "state", value: state)
            ]
        }
        guard let url = components.url else { throw SocialOAuthError.invalidRedirectURI }
        return url
    }

    private static func generatePKCE() -> (codeVerifier: String, codeChallenge: String) {
        let codeVerifier = randomURLSafeString(length: 64)
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data(codeVerifier.utf8))
        let challenge = Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return (codeVerifier, challenge)
        #else
        return (codeVerifier, codeVerifier)
        #endif
    }

    private static func randomURLSafeString(length: Int) -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in charset.randomElement() })
    }
}

final class GeminiAssistantService {
    private let session: URLSession
    private let apiKey: String?

    static var isConfigured: Bool {
        let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        return !key.isEmpty
    }

    init(session: URLSession = .shared) {
        self.session = session
        self.apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
    }

    func analyze(text: String, imageData: Data?) async throws -> UnifiedAssistantOutput {
        guard let apiKey, !apiKey.isEmpty else {
            throw NSError(domain: "Gemini", code: 1, userInfo: [NSLocalizedDescriptionKey: "Gemini API key not configured."])
        }
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "Gemini", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini endpoint URL."])
        }

        let prompt = """
        You are an AI fitness assistant. Return STRICT JSON only with keys:
        reply (string),
        intent ("workout"|"nutrition"|"chat"),
        workout {exercise,sets,reps,weight,rpe} or null,
        meal {name,calories,protein,carbs,fat} or null.
        If user provides workout details, set intent=workout and fill workout.
        If user provides food/photo nutrition details, set intent=nutrition and fill meal.
        IMPORTANT:
        - reply must be English only.
        - reply must contain NO Chinese characters (no Han characters), and no bilingual text.
        - reply should use ASCII English (letters/numbers/common punctuation/spaces only).
        - If the user input is Chinese, still respond in English.
        User input: \(text)
        """

        var parts: [[String: Any]] = [["text": prompt]]
        if let imageData {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": imageData.base64EncodedString()
                ]
            ])
        }

        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": parts]
            ],
            "generationConfig": ["temperature": 0.2]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw NSError(domain: "Gemini", code: 3, userInfo: [NSLocalizedDescriptionKey: "Gemini request failed."])
        }
        guard let raw = extractGeminiText(from: data), let parsed = parseOutput(from: raw) else {
            throw NSError(domain: "Gemini", code: 4, userInfo: [NSLocalizedDescriptionKey: "Gemini response parsing failed."])
        }
        return parsed
    }

    func inferMuscleContributions(exerciseName: String) async throws -> [String: Double] {
        guard let apiKey, !apiKey.isEmpty else {
            throw NSError(domain: "Gemini", code: 1, userInfo: [NSLocalizedDescriptionKey: "Gemini API key not configured."])
        }
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "Gemini", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini endpoint URL."])
        }

        let groups = MuscleCatalog.allGroups.joined(separator: ", ")
        let prompt = """
        You are a sports science assistant.
        Given an exercise name, estimate how much each muscle group contributes.
        Return STRICT JSON only with this exact structure:
        {
          "contributions": {
            "<MUSCLE_GROUP_1>": number,
            "<MUSCLE_GROUP_2>": number,
            ...
          }
        }
        Requirements:
        - Use EXACTLY these muscle group keys (spelling must match exactly):
          \(groups)
        - Values must be decimals between 0 and 1.
        - Values should sum to 1.0 (within a small rounding error).
        - No extra text, no extra keys.

        Exercise name: \(exerciseName)
        """

        let parts: [[String: Any]] = [["text": prompt]]
        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": parts]
            ],
            "generationConfig": ["temperature": 0.2]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw NSError(domain: "Gemini", code: 3, userInfo: [NSLocalizedDescriptionKey: "Gemini request failed."])
        }
        guard let raw = extractGeminiText(from: data), let parsed = parseContributions(from: raw) else {
            throw NSError(domain: "Gemini", code: 4, userInfo: [NSLocalizedDescriptionKey: "Gemini contributions parsing failed."])
        }
        return parsed
    }

    private func extractGeminiText(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else { return nil }
        return text
    }

    private func parseContributions(from text: String) -> [String: Double]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let data = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        guard let contributionsAny = json["contributions"] as? [String: Any] else { return nil }
        var result: [String: Double] = [:]
        for (k, v) in contributionsAny {
            switch v {
            case let d as Double:
                result[k] = d
            case let i as Int:
                result[k] = Double(i)
            case let s as String:
                result[k] = Double(s) ?? 0
            default:
                break
            }
        }
        return result.isEmpty ? nil : result
    }

    private func sanitizeGeminiReply(_ rawReply: String) -> String {
        // Hard guardrail: regardless of model output, never display Chinese characters.
        // We detect any Han characters (\p{Han}) and fall back to a safe English prompt.
        if rawReply.range(of: "\\p{Han}", options: .regularExpression) != nil {
            return "Understood. Please provide workout details (exercise, sets, reps, weight, RPE) or meal macros (name, calories, protein, carbs, fat)."
        }

        return rawReply
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseOutput(from text: String) -> UnifiedAssistantOutput? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let data = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let replyRaw = (json["reply"] as? String) ?? "Done."
        let reply = sanitizeGeminiReply(replyRaw)
        let intentRaw = (json["intent"] as? String) ?? "chat"
        let intent = UnifiedAssistantIntent(rawValue: intentRaw) ?? .chat

        var workout: (exercise: String, sets: Int, reps: Int, weight: Double, rpe: Int)?
        if let w = json["workout"] as? [String: Any] {
            var exercise = (w["exercise"] as? String) ?? "Workout"
            if exercise.range(of: "\\p{Han}", options: .regularExpression) != nil {
                exercise = "Workout"
            }
            let sets = (w["sets"] as? Int) ?? 0
            let reps = (w["reps"] as? Int) ?? 0
            let weight = (w["weight"] as? Double) ?? Double((w["weight"] as? Int) ?? 0)
            let rpe = (w["rpe"] as? Int) ?? 7
            if sets > 0, reps > 0 { workout = (exercise, sets, reps, weight, rpe) }
        }

        var meal: (name: String, calories: Int, protein: Int, carbs: Int, fat: Int)?
        if let m = json["meal"] as? [String: Any] {
            var name = (m["name"] as? String) ?? "Meal"
            if name.range(of: "\\p{Han}", options: .regularExpression) != nil {
                name = "Meal"
            }
            let calories = (m["calories"] as? Int) ?? 0
            let protein = (m["protein"] as? Int) ?? 0
            let carbs = (m["carbs"] as? Int) ?? 0
            let fat = (m["fat"] as? Int) ?? 0
            if calories > 0 { meal = (name, calories, protein, carbs, fat) }
        }
        return UnifiedAssistantOutput(reply: reply, intent: intent, workout: workout, meal: meal)
    }
}

#if canImport(AuthenticationServices)
extension SocialOAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(AppKit)
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
#endif

final class VoicePermissionManager {
    func requestAccess() async -> (status: VoicePermissionStatus, message: String) {
        #if canImport(AVFoundation) && canImport(Speech)
        let micGranted = await requestMicrophonePermission()
        guard micGranted else {
            return (.denied, "Microphone permission denied. Enable it in System Settings > Privacy.")
        }

        let speechStatus = await requestSpeechPermission()
        switch speechStatus {
        case .authorized:
            return (.granted, "Voice input is ready.")
        case .denied, .restricted:
            return (.denied, "Speech recognition permission denied. Enable it in System Settings > Privacy.")
        case .notDetermined:
            return (.notRequested, "Speech recognition permission has not been determined.")
        @unknown default:
            return (.unavailable, "Speech recognition status is unavailable.")
        }
        #else
        return (.unavailable, "Speech permissions are unavailable on this platform.")
        #endif
    }

    #if canImport(AVFoundation)
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    #endif

    #if canImport(Speech)
    private func requestSpeechPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    #endif
}

final class VoiceTranscriptionService {
    #if canImport(AVFoundation) && canImport(Speech)
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    #endif

    func start(
        onText: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        #if canImport(AVFoundation) && canImport(Speech)
        stop()
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            onError("Speech recognizer is unavailable.")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onError("Failed to configure audio session: \(error.localizedDescription)")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            onError("Failed to start audio engine: \(error.localizedDescription)")
            return
        }

        task = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                onText(result.bestTranscription.formattedString)
            }
            if let error {
                onError("Voice transcription error: \(error.localizedDescription)")
                self?.stop()
            }
        }
        #else
        onError("Voice transcription is unavailable on this platform.")
        #endif
    }

    func stop() {
        #if canImport(AVFoundation) && canImport(Speech)
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}

struct CoachEngine {
    func generate(context: CoachContext) -> CoachAdvice {
        let fatigued = context.recoveryItems.filter { $0.status == .fatigued }.map(\.muscleName)
        let recovering = context.recoveryItems.filter { $0.status == .recovering }.map(\.muscleName)
        let proteinRemaining = max(0, context.dashboard.proteinGoal - context.dashboard.proteinConsumed)
        let caloriesRemaining = max(0, context.dashboard.calorieGoal - context.dashboard.caloriesConsumed)
        let isSleepDebt = context.healthInsights.contains { $0.localizedCaseInsensitiveContains("Sleep Debt") }
        let isHRVDown = context.healthInsights.contains { $0.localizedCaseInsensitiveContains("HRV Down") }
        let isRHRElevated = context.healthInsights.contains { $0.localizedCaseInsensitiveContains("RHR Elevated") }
        let isLoadHigh = context.healthInsights.contains { $0.localizedCaseInsensitiveContains("Load High") }
        let cautionCount = [isSleepDebt, isHRVDown, isRHRElevated, isLoadHigh].filter { $0 }.count

        let training: String
        if cautionCount >= 2 {
            training = "Recovery-protection mode: reduce total volume by ~30-40%, keep RPE <= 7, and skip max-effort compounds."
        } else if cautionCount == 1 {
            training = "Caution day: keep intensity moderate, leave 2-3 reps in reserve, and prioritize technique quality."
        } else if context.dashboard.readinessScore >= 80 {
            training = "Today is green-light. Run \(context.dashboard.trainingRecommendation) with normal intensity."
        } else if context.dashboard.readinessScore >= 60 {
            training = "Use moderate intensity today. Keep 1-2 reps in reserve on key sets."
        } else {
            training = "Recovery-first day. Avoid heavy compounds and favor mobility/cardio."
        }

        let nutritionBase = "Remaining \(caloriesRemaining) kcal and \(proteinRemaining)g protein. Meals logged today: \(context.mealsToday)."
        let nutrition: String
        if isSleepDebt || isHRVDown {
            nutrition = "\(nutritionBase) Add hydration + protein earlier in the day and avoid aggressive calorie deficit."
        } else {
            nutrition = nutritionBase
        }
        let recovery = "Fatigued muscles: \(fatigued.isEmpty ? "none" : fatigued.joined(separator: ", ")). Recovering: \(recovering.isEmpty ? "none" : recovering.joined(separator: ", ")). Health signals: \(context.healthInsights.isEmpty ? "none" : context.healthInsights.joined(separator: " | "))."
        let warning = fatigued.isEmpty ? "No immediate overtraining risk detected." : "Avoid direct heavy loading for \(fatigued.joined(separator: ", "))."

        let missingData: String
        switch context.healthStatus {
        case .authorized:
            missingData = "No critical missing data."
        case .notRequested:
            missingData = "Health data not authorized yet. Advice uses workout + nutrition logs only."
        case .unavailable:
            missingData = "HealthKit unavailable on this platform. Using conservative estimates."
        case .denied:
            missingData = "Health access denied. Enable permissions for better readiness accuracy."
        }
        let planNotice = context.subscriptionPlan == .pro
            ? "Pro plan active: advanced AI features unlocked."
            : "Free plan: meal scanning quota is limited."

        return CoachAdvice(
            readinessScore: context.dashboard.readinessScore,
            training: training,
            nutrition: nutrition,
            recovery: recovery,
            warning: "\(warning) \(planNotice)",
            missingData: missingData
        )
    }
}
