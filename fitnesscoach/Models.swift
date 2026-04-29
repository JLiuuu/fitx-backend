import SwiftUI

enum HeightUnit: String, Codable, CaseIterable {
    case cm
    case ftIn
}

enum WeightUnit: String, Codable, CaseIterable {
    case kg
    case lbs
}

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        self = Sex(rawValue: raw) ?? .male
    }
}

enum PrimaryGoal: String, Codable, CaseIterable, Identifiable {
    case muscleGain = "Muscle Gain"
    case fatLoss = "Fat Loss"

    var id: String { rawValue }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .low: return 1.3
        case .medium: return 1.45
        case .high: return 1.6
        }
    }
}

struct UserProfile: Codable {
    let age: Int
    let sex: Sex
    let heightCm: Double
    let weightKg: Double
    let preferredHeightUnit: HeightUnit
    let preferredWeightUnit: WeightUnit
    let primaryGoal: PrimaryGoal
    let activityLevel: ActivityLevel
    let calorieDeltaGoalKcal: Int
    let dailyWorkoutGoalKcal: Int

    var bmi: Double {
        guard heightCm > 0 else { return 0 }
        let meters = heightCm / 100.0
        return weightKg / (meters * meters)
    }

    var bmr: Double {
        // Mifflin-St Jeor baseline.
        let sexOffset: Double
        switch sex {
        case .male: sexOffset = 5
        case .female: sexOffset = -161
        }
        return (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + sexOffset
    }

    enum CodingKeys: String, CodingKey {
        case age, sex, heightCm, weightKg, preferredHeightUnit, preferredWeightUnit, primaryGoal, activityLevel, calorieDeltaGoalKcal, dailyWorkoutGoalKcal
    }

    init(
        age: Int,
        sex: Sex,
        heightCm: Double,
        weightKg: Double,
        preferredHeightUnit: HeightUnit,
        preferredWeightUnit: WeightUnit,
        primaryGoal: PrimaryGoal,
        activityLevel: ActivityLevel,
        calorieDeltaGoalKcal: Int,
        dailyWorkoutGoalKcal: Int
    ) {
        self.age = age
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.preferredHeightUnit = preferredHeightUnit
        self.preferredWeightUnit = preferredWeightUnit
        self.primaryGoal = primaryGoal
        self.activityLevel = activityLevel
        self.calorieDeltaGoalKcal = calorieDeltaGoalKcal
        self.dailyWorkoutGoalKcal = dailyWorkoutGoalKcal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        age = try container.decode(Int.self, forKey: .age)
        sex = try container.decode(Sex.self, forKey: .sex)
        heightCm = try container.decode(Double.self, forKey: .heightCm)
        weightKg = try container.decode(Double.self, forKey: .weightKg)
        preferredHeightUnit = try container.decode(HeightUnit.self, forKey: .preferredHeightUnit)
        preferredWeightUnit = try container.decode(WeightUnit.self, forKey: .preferredWeightUnit)
        primaryGoal = try container.decodeIfPresent(PrimaryGoal.self, forKey: .primaryGoal) ?? .muscleGain
        activityLevel = try container.decodeIfPresent(ActivityLevel.self, forKey: .activityLevel) ?? .medium
        calorieDeltaGoalKcal = try container.decodeIfPresent(Int.self, forKey: .calorieDeltaGoalKcal)
            ?? (primaryGoal == .muscleGain ? 700 : -700)
        dailyWorkoutGoalKcal = try container.decodeIfPresent(Int.self, forKey: .dailyWorkoutGoalKcal) ?? 300
    }
}

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

    func withNutritionGoals(calorieGoal: Int, proteinGoal: Int, carbsGoal: Int, fatGoal: Int) -> TodayDashboard {
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

    func withNutritionConsumed(calories: Int, protein: Int, carbs: Int, fat: Int) -> TodayDashboard {
        TodayDashboard(
            readinessScore: readinessScore,
            statusText: statusText,
            trainingRecommendation: trainingRecommendation,
            calorieGoal: calorieGoal,
            caloriesConsumed: max(0, calories),
            proteinGoal: proteinGoal,
            proteinConsumed: max(0, protein),
            carbsGoal: carbsGoal,
            carbsConsumed: max(0, carbs),
            fatGoal: fatGoal,
            fatConsumed: max(0, fat)
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

enum MuscleCatalog {
    static let frontGroups: [String] = [
        "Chest",
        "Shoulders (Front/Mid)",
        "Biceps",
        "Abs",
        "Quads"
    ]

    static let backGroups: [String] = [
        "Upper Back (Traps)",
        "Lower Back",
        "Triceps",
        "Lats",
        "Glutes",
        "Hamstrings"
    ]

    static let allGroups: [String] = frontGroups + backGroups
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
    let id: UUID
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let confidence: Double
    let needsConfirmation: Bool
    let questions: [String]
    let loggedAt: Date
    let source: MealSource
}

enum MealSource: String, Codable {
    case manual = "Manual"
    case aiScan = "AI Scan"
}

enum NutritionTimeRange: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: String { rawValue }
}

struct NutritionSummary {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let mealCount: Int
}

enum NutritionTrendWindow: String, CaseIterable, Identifiable {
    case sevenDays = "7D"
    case thirtyDays = "30D"

    var id: String { rawValue }

    var dayCount: Int {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        }
    }
}

struct NutritionTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct WorkoutTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Int
}

struct CoachAdvice {
    let readinessScore: Int
    let training: String
    let nutrition: String
    let recovery: String
    let warning: String
    let missingData: String

    static func generate(from dashboard: TodayDashboard, recoveryItems: [MuscleRecoveryItem]) -> CoachAdvice {
        let fatiguedMuscles = recoveryItems.filter { $0.status == .fatigued }.map(\.muscleName)
        let avoidText = fatiguedMuscles.isEmpty ? "none" : fatiguedMuscles.joined(separator: ", ")
        let proteinRemaining = max(0, dashboard.proteinGoal - dashboard.proteinConsumed)
        let caloriesRemaining = max(0, dashboard.calorieGoal - dashboard.caloriesConsumed)
        let maxRemainingHours = recoveryItems.map(\.remainingHours).max() ?? 0

        return CoachAdvice(
            readinessScore: dashboard.readinessScore,
            training: "Recommended: \(dashboard.trainingRecommendation). Avoid heavy loading for: \(avoidText).",
            nutrition: "Remaining today: \(caloriesRemaining) kcal, \(proteinRemaining)g protein.",
            recovery: "Longest estimated recovery window: \(maxRemainingHours)h. Keep sleep >= 7.5h.",
            warning: fatiguedMuscles.isEmpty ? "No high-risk signal today." : "High fatigue detected in \(avoidText). Reduce volume.",
            missingData: "No missing data."
        )
    }
}

enum TrainingIntensityLevel {
    case green
    case caution
    case protect

    var title: String {
        switch self {
        case .green: return "Green"
        case .caution: return "Caution"
        case .protect: return "Protect"
        }
    }

    var guidance: String {
        switch self {
        case .green: return "Normal intensity is acceptable."
        case .caution: return "Use moderate load and keep reps in reserve."
        case .protect: return "Reduce volume and avoid max-effort lifts."
        }
    }

    var color: Color {
        switch self {
        case .green: return .green
        case .caution: return .yellow
        case .protect: return .red
        }
    }
}

struct TrainingSignalExplanation: Identifiable {
    let id: String
    let title: String
    let meaning: String
    let todayAction: String

    static func from(reason: String) -> TrainingSignalExplanation {
        if reason.localizedCaseInsensitiveContains("Sleep Debt") {
            return TrainingSignalExplanation(
                id: "sleep-debt",
                title: "Sleep Debt",
                meaning: "Recent sleep duration or quality is below your recovery target.",
                todayAction: "Reduce training volume and keep at least 2-3 reps in reserve."
            )
        }
        if reason.localizedCaseInsensitiveContains("HRV Down") {
            return TrainingSignalExplanation(
                id: "hrv-down",
                title: "HRV Down",
                meaning: "Autonomic recovery signal is lower than your baseline.",
                todayAction: "Avoid max effort work and prioritize technique-focused sets."
            )
        }
        if reason.localizedCaseInsensitiveContains("RHR Elevated") {
            return TrainingSignalExplanation(
                id: "rhr-elevated",
                title: "RHR Elevated",
                meaning: "Resting heart rate is above baseline, often linked to stress or accumulated fatigue.",
                todayAction: "Use conservative loads and extend warm-up and between-set recovery."
            )
        }
        if reason.localizedCaseInsensitiveContains("Load High") {
            return TrainingSignalExplanation(
                id: "load-high",
                title: "Load High",
                meaning: "Recent total activity load is high relative to your recovery inputs.",
                todayAction: "Cut total working sets and avoid adding extra accessory volume."
            )
        }
        return TrainingSignalExplanation(
            id: "no-risk",
            title: "No Major Risk Signals",
            meaning: "No critical recovery warnings were detected from current health signals.",
            todayAction: "Proceed with normal intensity and monitor perceived exertion."
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

struct WorkoutLogItem: Identifiable {
    let id: UUID
    let exerciseName: String
    let sets: Int
    let reps: Int
    let weight: Double
    let rpe: Int
    let estimatedCalories: Int
    let loggedAt: Date
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

enum VoicePermissionStatus: String {
    case notRequested = "Not Requested"
    case granted = "Granted"
    case denied = "Denied"
    case unavailable = "Unavailable on this platform"
}

struct HealthSyncResult {
    let status: HealthAuthorizationStatus
    let summary: String
    let readinessScore: Int?
    let insights: [String]
    let exerciseMinutes: Double?
}

enum SubscriptionPlan: String {
    case free = "Free"
    case pro = "Pro"
}

struct CoachContext {
    let dashboard: TodayDashboard
    let recoveryItems: [MuscleRecoveryItem]
    let mealsToday: Int
    let healthStatus: HealthAuthorizationStatus
    let healthInsights: [String]
    let subscriptionPlan: SubscriptionPlan
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
        .init(muscleName: "Shoulders (Front/Mid)", status: .recovering, fatigueScore: 56, remainingHours: 16),
        .init(muscleName: "Biceps", status: .ready, fatigueScore: 30, remainingHours: 8),
        .init(muscleName: "Abs", status: .ready, fatigueScore: 24, remainingHours: 6),
        .init(muscleName: "Quads", status: .fatigued, fatigueScore: 81, remainingHours: 26),
        .init(muscleName: "Upper Back (Traps)", status: .ready, fatigueScore: 28, remainingHours: 8),
        .init(muscleName: "Lower Back", status: .ready, fatigueScore: 35, remainingHours: 10),
        .init(muscleName: "Triceps", status: .recovering, fatigueScore: 58, remainingHours: 17),
        .init(muscleName: "Lats", status: .ready, fatigueScore: 26, remainingHours: 8),
        .init(muscleName: "Glutes", status: .recovering, fatigueScore: 59, remainingHours: 18),
        .init(muscleName: "Hamstrings", status: .recovering, fatigueScore: 57, remainingHours: 17)
    ]

    static let meals: [MealItem] = [
        .init(id: UUID(), name: "Chicken Breast + Rice", calories: 620, protein: 48, carbs: 72, fat: 14, confidence: 0.92, needsConfirmation: false, questions: [], loggedAt: Date(), source: .manual),
        .init(id: UUID(), name: "Greek Yogurt + Berries", calories: 260, protein: 24, carbs: 28, fat: 6, confidence: 0.89, needsConfirmation: false, questions: [], loggedAt: Date(), source: .manual)
    ]

    static let coachAdvice = CoachAdvice(
        readinessScore: 82,
        training: "Recommend Pull Day at moderate intensity. Avoid heavy squats today.",
        nutrition: "You still need ~62g protein. Add a high-protein dinner with moderate carbs.",
        recovery: "Legs need around 24h more recovery. Aim for 7.5h sleep tonight.",
        warning: "If soreness or fatigue worsens, reduce load and prioritize recovery.",
        missingData: "No missing data."
    )
}
