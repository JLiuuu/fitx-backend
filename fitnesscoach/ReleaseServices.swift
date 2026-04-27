import Foundation
import StoreKit

enum AppConfig {
    static let backendBaseURLString = ProcessInfo.processInfo.environment["FITNESS_BACKEND_URL"] ?? "http://localhost:8000"
    static let proMonthlyProductID = "com.fitnesscoach.pro.monthly"
    static let proYearlyProductID = "com.fitnesscoach.pro.yearly"
}

enum APIError: Error {
    case invalidURL
    case invalidResponse
}

struct CoachAPIResponse: Codable {
    let readinessScore: Int
    let training: String
    let nutrition: String
    let recovery: String
    let warning: String
    let missingData: String
}

final class APIClient {
    private let session: URLSession
    private let baseURL: URL?

    init(session: URLSession = .shared, baseURLString: String = AppConfig.backendBaseURLString) {
        self.session = session
        self.baseURL = URL(string: baseURLString)
    }

    func scanMeal(userID: String, mealType: String) async throws -> MealScanResult {
        guard let baseURL else { throw APIError.invalidURL }
        let url = baseURL.appending(path: "/api/meal/scan")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["userId": userID, "mealType": mealType]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(MealScanAPIResponse.self, from: data)
        return decoded.toDomain()
    }

    func fetchTodayCoach(userID: String, dashboard: TodayDashboard, recoveryItems: [MuscleRecoveryItem], mealsCount: Int) async throws -> CoachAdvice {
        guard let baseURL else { throw APIError.invalidURL }
        let url = baseURL.appending(path: "/api/coach/today")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = CoachRequestPayload(
            userId: userID,
            readinessScore: dashboard.readinessScore,
            caloriesConsumed: dashboard.caloriesConsumed,
            calorieGoal: dashboard.calorieGoal,
            mealsCount: mealsCount,
            fatiguedMuscles: recoveryItems.filter { $0.status == .fatigued }.map(\.muscleName)
        )
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw APIError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(CoachAPIResponse.self, from: data)
        return CoachAdvice(
            readinessScore: decoded.readinessScore,
            training: decoded.training,
            nutrition: decoded.nutrition,
            recovery: decoded.recovery,
            warning: decoded.warning,
            missingData: decoded.missingData
        )
    }
}

private struct CoachRequestPayload: Codable {
    let userId: String
    let readinessScore: Int
    let caloriesConsumed: Int
    let calorieGoal: Int
    let mealsCount: Int
    let fatiguedMuscles: [String]
}

private struct MealScanAPIResponse: Codable {
    let mealName: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let confidence: Double
    let needsUserConfirmation: Bool
    let questions: [String]
    let foods: [FoodAPIResponse]

    func toDomain() -> MealScanResult {
        MealScanResult(
            meal: MealItem(
                name: mealName,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                confidence: confidence,
                needsConfirmation: needsUserConfirmation,
                questions: questions
            ),
            foods: foods.map { DetectedFood(name: $0.name, estimatedWeightGram: $0.estimatedWeightGram, confidence: $0.confidence) }
        )
    }
}

private struct FoodAPIResponse: Codable {
    let name: String
    let estimatedWeightGram: Int
    let confidence: Double
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var activePlan: SubscriptionPlan = .free
    @Published private(set) var lastSyncStatus: String = "Subscription not synced yet."

    func refreshEntitlements() async {
        do {
            let products = try await Product.products(for: [AppConfig.proMonthlyProductID, AppConfig.proYearlyProductID])
            guard !products.isEmpty else {
                activePlan = .free
                lastSyncStatus = "No StoreKit products found. Using Free plan."
                return
            }

            var hasActivePro = false
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result,
                   [AppConfig.proMonthlyProductID, AppConfig.proYearlyProductID].contains(transaction.productID) {
                    hasActivePro = true
                    break
                }
            }
            activePlan = hasActivePro ? .pro : .free
            lastSyncStatus = hasActivePro ? "Active Pro subscription detected." : "No active subscription. Free plan."
        } catch {
            activePlan = .free
            lastSyncStatus = "StoreKit sync failed: \(error.localizedDescription)"
        }
    }
}
