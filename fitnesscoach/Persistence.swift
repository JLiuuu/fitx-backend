import Foundation

struct PersistedState: Codable {
    var dashboard: DashboardDTO
    var recoveryItems: [MuscleRecoveryDTO]
    var workoutLogs: [WorkoutLogDTO]?
    var meals: [MealDTO]
    var coachAdvice: CoachAdviceDTO
    var healthStatus: String
    var latestHealthSummary: String
    var healthInsights: [String]?
    var lastWorkoutSummary: String
    var lastMealDetectionSummary: String
    var subscriptionPlan: String
    var dailyMealScanCount: Int
    var mealScanDailyLimit: Int
    var lastSubscriptionMessage: String
    var useLiveBackend: Bool
    var backendStatusMessage: String
    var showSignalExplanations: Bool?
    var isAuthenticated: Bool?
    var hasCompletedOnboarding: Bool?
    var authMethod: String?
    var authIdentifier: String?
    var userProfile: UserProfile?
    var plannedTrainingWeekdays: [Int]?
    var aiAssistantDailyCount: Int?
    var aiAssistantLastUsedDay: String?
    // exerciseKey (lowercased) -> muscleKey (lowercased group name) -> weight
    var customExerciseContributions: [String: [String: Double]]?
}

struct DashboardDTO: Codable {
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
}

struct MuscleRecoveryDTO: Codable {
    let muscleName: String
    let status: String
    let fatigueScore: Int
    let remainingHours: Int
}

struct WorkoutLogDTO: Codable {
    let id: String
    let exerciseName: String
    let sets: Int
    let reps: Int
    let weight: Double
    let rpe: Int
    let estimatedCalories: Int
    let loggedAt: Date
}

struct MealDTO: Codable {
    let id: String
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let confidence: Double
    let needsConfirmation: Bool
    let questions: [String]
    let loggedAt: Date
    let source: String

    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat, confidence, needsConfirmation, questions, loggedAt, source
    }

    init(
        id: String,
        name: String,
        calories: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        confidence: Double,
        needsConfirmation: Bool,
        questions: [String],
        loggedAt: Date,
        source: String
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.confidence = confidence
        self.needsConfirmation = needsConfirmation
        self.questions = questions
        self.loggedAt = loggedAt
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        calories = try container.decode(Int.self, forKey: .calories)
        protein = try container.decode(Int.self, forKey: .protein)
        carbs = try container.decode(Int.self, forKey: .carbs)
        fat = try container.decode(Int.self, forKey: .fat)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 1.0
        needsConfirmation = try container.decodeIfPresent(Bool.self, forKey: .needsConfirmation) ?? false
        questions = try container.decodeIfPresent([String].self, forKey: .questions) ?? []
        loggedAt = try container.decodeIfPresent(Date.self, forKey: .loggedAt) ?? Date()
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? MealSource.manual.rawValue
    }
}

struct CoachAdviceDTO: Codable {
    let readinessScore: Int
    let training: String
    let nutrition: String
    let recovery: String
    let warning: String
    let missingData: String
}

final class PersistenceService {
    private let saveURL: URL

    init(filename: String = "fitnesscoach_state.json") {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.saveURL = root.appendingPathComponent(filename)
    }

    func save(_ state: PersistedState) {
        do {
            let data = try JSONEncoder().encode(state)
            try FileManager.default.createDirectory(
                at: saveURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: saveURL, options: [.atomic])
        } catch {
            print("Persistence save failed: \(error.localizedDescription)")
        }
    }

    func load() -> PersistedState? {
        guard let data = try? Data(contentsOf: saveURL) else {
            return nil
        }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }

    func export(_ state: PersistedState) throws -> URL {
        let fileName = "fitnesscoach_export_\(Self.timestampString()).json"
        let outputURL = exportDirectory().appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: outputURL, options: [.atomic])
        return outputURL
    }

    private func exportDirectory() -> URL {
        if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            return downloads
        }
        return FileManager.default.temporaryDirectory
    }

    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}
