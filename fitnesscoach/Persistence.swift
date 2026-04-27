import Foundation

struct PersistedState: Codable {
    var dashboard: DashboardDTO
    var recoveryItems: [MuscleRecoveryDTO]
    var meals: [MealDTO]
    var coachAdvice: CoachAdviceDTO
    var healthStatus: String
    var latestHealthSummary: String
    var lastWorkoutSummary: String
    var lastMealDetectionSummary: String
    var subscriptionPlan: String
    var dailyMealScanCount: Int
    var mealScanDailyLimit: Int
    var lastSubscriptionMessage: String
    var useLiveBackend: Bool
    var backendStatusMessage: String
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

struct MealDTO: Codable {
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let confidence: Double
    let needsConfirmation: Bool
    let questions: [String]
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
}
