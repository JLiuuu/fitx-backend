import SwiftUI

struct TodayDashboard {
    let readinessScore: Int
    let statusText: String
    let trainingRecommendation: String
    let calorieGoal: Int
    let caloriesConsumed: Int
    let proteinGoal: Int
    let proteinConsumed: Int
    let carbsGoal: Int
    let carbsConsumed: Int
    let fatGoal: Int
    let fatConsumed: Int

    func withReadiness(_ score: Int) -> TodayDashboard {
        let safeScore = max(0, min(100, score))
        let status: String
        if safeScore >= 80 {
            status = "Ready for training"
        } else if safeScore >= 60 {
            status = "Train with moderate intensity"
        } else {
            status = "Prioritize recovery today"
        }

        return TodayDashboard(
            readinessScore: safeScore,
            statusText: status,
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

    func withNutritionDelta(calories: Int, protein: Int, carbs: Int, fat: Int) -> TodayDashboard {
        TodayDashboard(
            readinessScore: readinessScore,
            statusText: statusText,
            trainingRecommendation: trainingRecommendation,
            calorieGoal: calorieGoal,
            caloriesConsumed: caloriesConsumed + calories,
            proteinGoal: proteinGoal,
            proteinConsumed: proteinConsumed + protein,
            carbsGoal: carbsGoal,
            carbsConsumed: carbsConsumed + carbs,
            fatGoal: fatGoal,
            fatConsumed: fatConsumed + fat
        )
    }
}

struct MuscleRecoveryItem: Identifiable {
    let id = UUID()
    let muscleName: String
    let status: RecoveryStatus
    let fatigueScore: Int
    let remainingHours: Int
}

enum RecoveryStatus: String {
    case ready = "Ready"
    case recovering = "Recovering"
    case fatigued = "Fatigued"
    case unknown = "Unknown"

    var color: Color {
        switch self {
        case .ready: .green
        case .recovering: .yellow
        case .fatigued: .red
        case .unknown: .gray
        }
    }
}

struct MealItem: Identifiable {
    let id = UUID()
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let confidence: Double
    let needsConfirmation: Bool
    let questions: [String]
}

struct CoachAdvice {
    let training: String
    let nutrition: String
    let recovery: String
    let warning: String

    static func generate(from dashboard: TodayDashboard, recoveryItems: [MuscleRecoveryItem]) -> CoachAdvice {
        let fatiguedMuscles = recoveryItems.filter { $0.status == .fatigued }.map(\.muscleName)
        let avoidText = fatiguedMuscles.isEmpty ? "none" : fatiguedMuscles.joined(separator: ", ")
        let proteinRemaining = max(0, dashboard.proteinGoal - dashboard.proteinConsumed)
        let caloriesRemaining = max(0, dashboard.calorieGoal - dashboard.caloriesConsumed)
        let maxRemainingHours = recoveryItems.map(\.remainingHours).max() ?? 0

        return CoachAdvice(
            training: "Recommended: \(dashboard.trainingRecommendation). Avoid heavy loading for: \(avoidText).",
            nutrition: "Remaining today: \(caloriesRemaining) kcal, \(proteinRemaining)g protein.",
            recovery: "Longest estimated recovery window: \(maxRemainingHours)h. Keep sleep >= 7.5h.",
            warning: fatiguedMuscles.isEmpty ? "No high-risk signal today." : "High fatigue detected in \(avoidText). Reduce volume."
        )
    }
}

struct WorkoutInput {
    let exerciseName: String
    let sets: Int
    let reps: Int
    let weight: Double
    let rpe: Int
}

struct MealScanResult {
    let meal: MealItem
    let foods: [DetectedFood]
}

struct DetectedFood: Identifiable {
    let id = UUID()
    let name: String
    let estimatedWeightGram: Int
    let confidence: Double
}

enum HealthAuthorizationStatus: String {
    case notRequested = "Not Requested"
    case authorized = "Authorized"
    case unavailable = "Unavailable on this platform"
    case denied = "Denied"
}

struct HealthSyncResult {
    let status: HealthAuthorizationStatus
    let summary: String
}

enum MockData {
    static let dashboard = TodayDashboard(
        readinessScore: 82,
        statusText: "Ready for Pull Day",
        trainingRecommendation: "Pull Day - Moderate Intensity",
        calorieGoal: 2300,
        caloriesConsumed: 1520,
        proteinGoal: 180,
        proteinConsumed: 118,
        carbsGoal: 250,
        carbsConsumed: 165,
        fatGoal: 70,
        fatConsumed: 45
    )

    static let recoveryItems: [MuscleRecoveryItem] = [
        .init(muscleName: "Chest", status: .recovering, fatigueScore: 62, remainingHours: 18),
        .init(muscleName: "Lats", status: .ready, fatigueScore: 26, remainingHours: 0),
        .init(muscleName: "Quads", status: .fatigued, fatigueScore: 81, remainingHours: 24),
        .init(muscleName: "Hamstrings", status: .recovering, fatigueScore: 59, remainingHours: 16)
    ]

    static let meals: [MealItem] = [
        .init(name: "Chicken Breast + Rice", calories: 620, protein: 48, carbs: 72, fat: 14, confidence: 0.92, needsConfirmation: false, questions: []),
        .init(name: "Greek Yogurt + Berries", calories: 260, protein: 24, carbs: 28, fat: 6, confidence: 0.89, needsConfirmation: false, questions: [])
    ]

    static let coachAdvice = CoachAdvice(
        training: "Recommend Pull Day at moderate intensity. Avoid heavy squats today.",
        nutrition: "You still need ~62g protein. Add a high-protein dinner with moderate carbs.",
        recovery: "Legs need around 24h more recovery. Aim for 7.5h sleep tonight.",
        warning: "If soreness or fatigue worsens, reduce load and prioritize recovery."
    )
}
