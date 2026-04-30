import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    private let appState: AppState
    init(appState: AppState) { self.appState = appState }
    var dashboard: TodayDashboard { appState.dashboard }
    var recoveryItems: [MuscleRecoveryItem] { appState.recoveryItems }
    var coachAdvice: CoachAdvice { appState.coachAdvice }
    var latestHealthSummary: String { appState.latestHealthSummary }
    var healthInsights: [String] { appState.healthInsights }
    var healthStatus: HealthAuthorizationStatus { appState.healthStatus }
    var showSignalExplanations: Bool { appState.showSignalExplanations }
    var trainingIntensityLevel: TrainingIntensityLevel {
        intensityEvaluation.level
    }
    var trainingIntensityReasons: [String] {
        intensityEvaluation.reasons
    }
    private var intensityEvaluation: (level: TrainingIntensityLevel, reasons: [String]) {
        computeTrainingIntensity(from: appState.healthInsights)
    }

    var totalBurnedKcal: Int {
        let bmr = Int((appState.userProfile?.bmr ?? 1650).rounded())
        return bmr + workoutBurnedKcal
    }
    var bmrKcal: Int {
        Int((appState.userProfile?.bmr ?? 1650).rounded())
    }
    var totalEatenKcal: Int { dashboard.caloriesConsumed }
    var netCalories: Int { totalBurnedKcal - totalEatenKcal }
    private var todaysWorkouts: [WorkoutLogItem] {
        let calendar = Calendar.current
        return appState.workoutLogs.filter { calendar.isDateInToday($0.loggedAt) }
    }
    var workoutBurnedKcal: Int { todaysWorkouts.reduce(0) { $0 + $1.estimatedCalories } }
    var workoutTargetKcal: Int { max(80, appState.userProfile?.dailyWorkoutGoalKcal ?? 300) }
    var workoutProgress: Double { min(1.0, Double(workoutBurnedKcal) / Double(max(1, workoutTargetKcal))) }
    var workoutDurationMinutes: Int {
        if appState.healthStatus == .authorized {
            return max(0, appState.todayExerciseMinutes)
        }
        return todaysWorkouts.reduce(0) { $0 + max(1, $1.sets) * 3 }
    }
    var workoutDurationTargetMinutes: Int { 60 }
    var workoutDurationProgress: Double {
        min(1.0, Double(workoutDurationMinutes) / Double(max(1, workoutDurationTargetMinutes)))
    }
    var netStatusText: String {
        if totalEatenKcal < totalBurnedKcal {
            return "Deficit \(totalBurnedKcal - totalEatenKcal) kcal"
        }
        return "Surplus \(totalEatenKcal - totalBurnedKcal) kcal"
    }
    var nutritionCaloriesDeltaText: String {
        if totalEatenKcal >= totalBurnedKcal {
            return "Today's Calories +\(totalEatenKcal - totalBurnedKcal) kcal (Surplus)"
        }
        return "Today's Calories -\(totalBurnedKcal - totalEatenKcal) kcal (Deficit)"
    }
    var intakeProgressText: String { "\(dashboard.caloriesConsumed)/\(dashboard.calorieGoal) kcal" }
    var proteinProgressText: String { "\(dashboard.proteinConsumed)/\(dashboard.proteinGoal) g" }
    var carbsProgressText: String { "\(dashboard.carbsConsumed)/\(dashboard.carbsGoal) g" }
    var fatProgressText: String { "\(dashboard.fatConsumed)/\(dashboard.fatGoal) g" }
    var calorieConsumed: Int { dashboard.caloriesConsumed }
    var calorieGoal: Int { max(1, dashboard.calorieGoal) }
    var calorieProgress: Double { min(1.0, Double(calorieConsumed) / Double(calorieGoal)) }
    var proteinConsumed: Int { dashboard.proteinConsumed }
    var proteinGoal: Int { max(1, dashboard.proteinGoal) }
    var proteinProgress: Double { min(1.0, Double(proteinConsumed) / Double(proteinGoal)) }
    var carbsConsumed: Int { dashboard.carbsConsumed }
    var carbsGoal: Int { max(1, dashboard.carbsGoal) }
    var carbsProgress: Double { min(1.0, Double(carbsConsumed) / Double(carbsGoal)) }
    var fatConsumed: Int { dashboard.fatConsumed }
    var fatGoal: Int { max(1, dashboard.fatGoal) }
    var fatProgress: Double { min(1.0, Double(fatConsumed) / Double(fatGoal)) }
    var aiCoachNutritionLine: String {
        let proteinLeft = max(0, proteinGoal - proteinConsumed)
        let carbsLeft = max(0, carbsGoal - carbsConsumed)
        let fatLeft = max(0, fatGoal - fatConsumed)
        let foods = recommendedFoods(proteinLeft: proteinLeft, carbsLeft: carbsLeft, fatLeft: fatLeft)
        return "1) Nutrition: remaining P \(proteinLeft)g / C \(carbsLeft)g / F \(fatLeft)g. Suggested foods: \(foods)."
    }
    var aiCoachRestLine: String {
        guard let mostFatigued = recoveryItems.max(by: { $0.fatigueScore < $1.fatigueScore }),
              mostFatigued.fatigueScore >= 40 else {
            return "2) Rest: no muscle requires strict rest today."
        }
        return "2) Rest: prioritize recovery for \(mostFatigued.muscleName) today."
    }
    var aiCoachTrainingLine: String {
        let candidates = recoveryItems
            .filter { $0.fatigueScore < 40 }
            .sorted { $0.fatigueScore < $1.fatigueScore }
        guard let primary = candidates.first?.muscleName else {
            return "3) Training: recovery is low overall, do mobility or light cardio."
        }
        return "3) Training: focus on \(primary). Recommended exercises: \(recommendedExercises(for: primary))."
    }

    func runBetaLoop() async {
        await appState.runBetaLoop()
    }

    private func recommendedFoods(proteinLeft: Int, carbsLeft: Int, fatLeft: Int) -> String {
        var picks: [String] = []
        if proteinLeft > 0 { picks.append("chicken breast, Greek yogurt") }
        if carbsLeft > 0 { picks.append("rice, oats, banana") }
        if fatLeft > 0 { picks.append("avocado, eggs, nuts") }
        return picks.isEmpty ? "target already met" : picks.joined(separator: "; ")
    }

    private func recommendedExercises(for muscle: String) -> String {
        switch muscle.lowercased() {
        case "chest":
            return "bench press, incline dumbbell press"
        case "shoulders (front/mid)":
            return "overhead press, lateral raise"
        case "biceps":
            return "barbell curl, incline dumbbell curl"
        case "triceps":
            return "rope pushdown, skull crusher"
        case "lats":
            return "lat pulldown, single-arm row"
        case "upper back (traps)":
            return "seated row, face pull"
        case "lower back":
            return "back extension, light RDL"
        case "abs":
            return "cable crunch, plank"
        case "quads":
            return "squat, leg press"
        case "glutes":
            return "hip thrust, Bulgarian split squat"
        case "hamstrings":
            return "Romanian deadlift, leg curl"
        default:
            return "compound lifts with moderate volume"
        }
    }
}

@MainActor
final class RecoveryViewModel: ObservableObject {
    private let appState: AppState
    init(appState: AppState) { self.appState = appState }
    var items: [MuscleRecoveryItem] { appState.recoveryItems }
    var lastWorkoutSummary: String { appState.lastWorkoutSummary }
    var readinessScore: Int { appState.dashboard.readinessScore }
}

@MainActor
final class WorkoutViewModel: ObservableObject {
    private let appState: AppState
    private let voiceTranscriber = VoiceTranscriptionService()
    init(appState: AppState) { self.appState = appState }

    var workoutLogs: [WorkoutLogItem] { appState.workoutLogs }
    var totalBurnedKcal: Int { appState.dashboard.calorieGoal }
    var trainingBurnKcal: Int { appState.workoutLogs.reduce(0) { $0 + $1.estimatedCalories } }
    /// Duration comes ONLY from Apple Watch / HealthKit (exercise minutes).
    /// If there is no data, the UI should show N/A.
    var trainingDurationMinutes: Int? {
        guard appState.healthStatus == .authorized else { return nil }
        let minutes = appState.todayExerciseMinutes
        return minutes > 0 ? minutes : nil
    }
    var trainingDurationTargetMinutes: Int { 60 }
    var trainingDurationProgress: Double? {
        guard let minutes = trainingDurationMinutes else { return nil }
        return min(1.0, Double(minutes) / Double(max(1, trainingDurationTargetMinutes)))
    }
    var restingBurnKcal: Int {
        Int((appState.userProfile?.bmr ?? 1650).rounded())
    }
    var activityBurnKcal: Int {
        max(0, totalBurnedKcal - restingBurnKcal - trainingBurnKcal)
    }
    var trainingIntensityLevel: TrainingIntensityLevel {
        intensityEvaluation.level
    }
    var trainingIntensityReasons: [String] {
        intensityEvaluation.reasons
    }
    var showSignalExplanations: Bool { appState.showSignalExplanations }
    var voicePermissionStatus: VoicePermissionStatus { appState.voicePermissionStatus }
    var voicePermissionMessage: String { appState.voicePermissionMessage }
    var useLiveBackend: Bool { appState.useLiveBackend }
    var vibePercent: Int { max(0, min(100, appState.dashboard.readinessScore)) }
    var vibeSuggestion: String {
        let fatigued = appState.recoveryItems.filter { $0.status == .fatigued }.map(\.muscleName)
        if vibePercent >= 80 {
            return "Suggestion: Go for your planned main lift, and add one strong accessory block."
        }
        if vibePercent >= 60 {
            return "Suggestion: Train moderately today, focus on technique and controlled volume."
        }
        if let first = fatigued.first {
            return "Suggestion: Avoid heavy loading on \(first), prioritize recovery-focused training."
        }
        return "Suggestion: Keep it light today and focus on mobility or low-intensity cardio."
    }
    private var intensityEvaluation: (level: TrainingIntensityLevel, reasons: [String]) {
        computeTrainingIntensity(from: appState.healthInsights)
    }

    /// Stored workout weight is always kg; UI entry follows profile preferred unit.
    private static let kgPerLb = 0.45359237

    var preferredWeightUnit: WeightUnit {
        appState.userProfile?.preferredWeightUnit ?? .kg
    }

    var weightFieldPlaceholder: String {
        preferredWeightUnit == .kg ? "Weight (kg)" : "Weight (lbs)"
    }

    var preferredWeightUnitShort: String {
        preferredWeightUnit == .kg ? "kg" : "lbs"
    }

    func displayWeightStringFromStoredKg(_ kg: Double) -> (value: String, unit: String) {
        if preferredWeightUnit == .lbs {
            let lbs = kg / Self.kgPerLb
            let s = abs(lbs - lbs.rounded()) < 0.05 ? "\(Int(lbs.rounded()))" : String(format: "%.1f", lbs)
            return (s, "lbs")
        }
        let k = kg
        let s = abs(k - k.rounded()) < 0.05 ? "\(Int(k.rounded()))" : String(format: "%.1f", k)
        return (s, "kg")
    }

    func workoutHistoryWeightSubtitle(for log: WorkoutLogItem) -> String {
        let (w, unit) = displayWeightStringFromStoredKg(log.weight)
        return "\(log.sets) sets x \(log.reps) reps @ \(w) \(unit), RPE \(log.rpe)"
    }

    private func weightEntryStringToKg(_ weight: String) -> Double {
        let trimmed = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let w = Double(trimmed) ?? 0
        return preferredWeightUnit == .lbs ? w * Self.kgPerLb : w
    }

    /// Maps transcript to a weight string suitable for the manual field (same unit as `preferredWeightUnit`).
    private func parsedWeightFieldString(from lower: String) -> String {
        let ns = lower as NSString
        let full = NSRange(location: 0, length: ns.length)

        func doubleAt(_ match: NSTextCheckingResult, index captureIndex: Int, in text: String) -> Double? {
            guard captureIndex < match.numberOfRanges,
                  let r = Range(match.range(at: captureIndex), in: text) else { return nil }
            return Double(String(text[r]))
        }

        if let regex = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)\\s*(kg|kgs|kilo|kilos)\\b", options: .caseInsensitive),
           let m = regex.firstMatch(in: lower, options: [], range: full),
           let kg = doubleAt(m, index: 1, in: lower) {
            return displayWeightStringFromStoredKg(kg).value
        }
        if let regex = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)\\s*(lb|lbs|pound|pounds)\\b", options: .caseInsensitive),
           let m = regex.firstMatch(in: lower, options: [], range: full),
           let lbs = doubleAt(m, index: 1, in: lower) {
            return displayWeightStringFromStoredKg(lbs * Self.kgPerLb).value
        }
        if let regex = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)\\s*公斤", options: []),
           let m = regex.firstMatch(in: lower, options: [], range: full),
           let kg = doubleAt(m, index: 1, in: lower) {
            return displayWeightStringFromStoredKg(kg).value
        }
        if let regex = try? NSRegularExpression(pattern: "@\\s*(\\d+(?:\\.\\d+)?)", options: .caseInsensitive),
           let m = regex.firstMatch(in: lower, options: [], range: full),
           let v = doubleAt(m, index: 1, in: lower) {
            let kg = preferredWeightUnit == .lbs ? v * Self.kgPerLb : v
            return displayWeightStringFromStoredKg(kg).value
        }
        return ""
    }

    func workoutTrend(window: NutritionTrendWindow) -> [WorkoutTrendPoint] {
        appState.workoutTrend(window: window)
    }

    func saveWorkout(exerciseName: String, sets: String, reps: String, weight: String, rpe: String) {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let workout = WorkoutInput(
            exerciseName: trimmedName,
            sets: Int(sets) ?? 0,
            reps: Int(reps) ?? 0,
            weight: weightEntryStringToKg(weight),
            rpe: Int(rpe) ?? 0
        )
        appState.addWorkout(input: workout)
    }

    func validateWorkoutInput(exerciseName: String, sets: String, reps: String, weight: String, rpe: String) -> String? {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return "Please enter an exercise name." }
        let setsValue = Int(sets) ?? 0
        let repsValue = Int(reps) ?? 0
        let weightKg = weightEntryStringToKg(weight)
        let rpeValue = Int(rpe) ?? 0
        if setsValue <= 0 { return "Sets must be greater than 0." }
        if repsValue <= 0 { return "Reps must be greater than 0." }
        if weightKg < 0 { return "Weight cannot be negative." }
        if !(1...10).contains(rpeValue) { return "RPE should be between 1 and 10." }
        return nil
    }

    func deleteWorkout(id: UUID) {
        appState.deleteWorkout(id: id)
    }

    func restoreWorkout(_ item: WorkoutLogItem) {
        appState.restoreWorkout(item)
    }

    func requestVoiceAccess() async {
        await appState.requestVoiceInputAccess()
    }

    func startVoiceTranscription(
        onText: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard appState.voicePermissionStatus == .granted else {
            onError("Enable voice permissions first.")
            return
        }
        voiceTranscriber.start(onText: onText, onError: onError)
    }

    func stopVoiceTranscription() {
        voiceTranscriber.stop()
    }

    func parseWorkoutInput(_ input: String) -> (exercise: String, sets: String, reps: String, weight: String, rpe: String)? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let lower = raw.lowercased()
        let sets = firstNonEmptyMatch(
            patterns: [
                "(\\d+)\\s*(set|sets)",
                "(\\d+)\\s*x\\s*\\d+",
                "(\\d+)\\s*组"
            ],
            in: lower
        ) ?? ""
        let reps = firstNonEmptyMatch(
            patterns: [
                "(\\d+)\\s*(rep|reps)",
                "\\d+\\s*x\\s*(\\d+)",
                "(\\d+)\\s*次"
            ],
            in: lower
        ) ?? ""
        let weight = parsedWeightFieldString(from: lower)
        let rpe = firstNonEmptyMatch(
            patterns: [
                "rpe\\s*(\\d+)",
                "rpe\\s*[:：]\\s*(\\d+)"
            ],
            in: lower
        ) ?? ""
        let exercise = lower.components(separatedBy: CharacterSet.decimalDigits).first?
            .replacingOccurrences(of: "sets", with: "")
            .replacingOccurrences(of: "set", with: "")
            .replacingOccurrences(of: "reps", with: "")
            .replacingOccurrences(of: "rep", with: "")
            .replacingOccurrences(of: "组", with: "")
            .replacingOccurrences(of: "次", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return (
            exercise.isEmpty ? "Workout" : exercise.capitalized,
            sets,
            reps,
            weight,
            rpe
        )
    }

    func workoutAssistantReply(for input: String) async -> (reply: String, parsed: (exercise: String, sets: String, reps: String, weight: String, rpe: String)?) {
        if useLiveBackend {
            do {
                let remote = try await appState.requestWorkoutAssistant(input: input)
                if remote.parsed != nil {
                    return (remote.reply + " (Remote)", remote.parsed)
                }
            } catch {
                // Fall through to local parser; UI remains unchanged.
            }
        }

        guard let parsed = parseWorkoutInput(input) else {
            return (Self.assistantParseFailureHint, nil)
        }
        let wKg = weightEntryStringToKg(parsed.weight)
        let estCalories = estimateWorkoutCalories(
            sets: Int(parsed.sets) ?? 0,
            reps: Int(parsed.reps) ?? 0,
            weight: wKg,
            rpe: Int(parsed.rpe) ?? 7
        )
        let modeSuffix = useLiveBackend ? " (Local fallback)" : " (Local)"
        let weightLine: String
        if parsed.weight.isEmpty {
            weightLine = "-"
        } else {
            weightLine = "\(parsed.weight) \(preferredWeightUnitShort)"
        }
        let reply = "Parsed workout: \(parsed.exercise), \(parsed.sets.isEmpty ? "-" : parsed.sets) sets, \(parsed.reps.isEmpty ? "-" : parsed.reps) reps, \(weightLine), RPE \(parsed.rpe.isEmpty ? "-" : parsed.rpe). Estimated burn: \(estCalories) kcal. Tap \"Add to Workout\" to save.\(modeSuffix)"
        return (reply, parsed)
    }

    func saveParsedWorkout(_ parsed: (exercise: String, sets: String, reps: String, weight: String, rpe: String)) {
        guard validateWorkoutInput(
            exerciseName: parsed.exercise,
            sets: parsed.sets,
            reps: parsed.reps,
            weight: parsed.weight,
            rpe: parsed.rpe
        ) == nil else { return }
        saveWorkout(
            exerciseName: parsed.exercise,
            sets: parsed.sets,
            reps: parsed.reps,
            weight: parsed.weight,
            rpe: parsed.rpe
        )
    }

    private func estimateWorkoutCalories(sets: Int, reps: Int, weight: Double, rpe: Int) -> Int {
        let volume = Double(max(1, sets) * max(1, reps))
        let intensity = Double(max(5, rpe)) / 10.0
        let weightFactor = max(1.0, weight / 30.0)
        let kcal = (volume * intensity * weightFactor) * 2.1
        return max(20, Int(kcal.rounded()))
    }

    private static let assistantParseFailureHint = "I could not parse your input. Please include clear numbers and units, for example: bench press 4 sets 8 reps 80 kg rpe 8."
}

private func computeTrainingIntensity(from healthInsights: [String]) -> (level: TrainingIntensityLevel, reasons: [String]) {
    let isSleepDebt = healthInsights.contains { $0.localizedCaseInsensitiveContains("Sleep Debt") }
    let isHRVDown = healthInsights.contains { $0.localizedCaseInsensitiveContains("HRV Down") }
    let isRHRElevated = healthInsights.contains { $0.localizedCaseInsensitiveContains("RHR Elevated") }
    let isLoadHigh = healthInsights.contains { $0.localizedCaseInsensitiveContains("Load High") }
    var reasons: [String] = []
    if isSleepDebt { reasons.append("Sleep Debt") }
    if isHRVDown { reasons.append("HRV Down") }
    if isRHRElevated { reasons.append("RHR Elevated") }
    if isLoadHigh { reasons.append("Load High") }
    let cautionCount = reasons.count
    if cautionCount >= 2 { return (.protect, reasons) }
    if cautionCount == 1 { return (.caution, reasons) }
    return (.green, ["No major recovery risk signals"])
}

@MainActor
final class NutritionViewModel: ObservableObject {
    private let appState: AppState
    private let voiceTranscriber = VoiceTranscriptionService()
    init(appState: AppState) { self.appState = appState }
    var meals: [MealItem] { appState.meals }
    var latestDetectionSummary: String { appState.lastMealDetectionSummary }
    var canScan: Bool { appState.canScanMeal() }
    var scanQuotaText: String { appState.remainingMealScansText() }
    var isPro: Bool { appState.subscriptionPlan == .pro }
    var useLiveBackend: Bool { appState.useLiveBackend }
    var proteinGoal: Int { appState.dashboard.proteinGoal }
    var carbsGoal: Int { appState.dashboard.carbsGoal }
    var fatGoal: Int { appState.dashboard.fatGoal }
    var calorieGoal: Int { appState.dashboard.calorieGoal }
    var primaryGoal: PrimaryGoal { appState.userProfile?.primaryGoal ?? .muscleGain }

    func requestMealScanPreview() async -> MealScanResult? {
        await appState.requestMealScanPreview()
    }

    func confirmScannedMeal(_ result: MealScanResult) {
        appState.confirmScannedMeal(result)
    }

    func addManualMeal(name: String, calories: Int, protein: Int, carbs: Int, fat: Int) {
        appState.addManualMeal(name: name, calories: calories, protein: protein, carbs: carbs, fat: fat)
    }

    func validateManualMeal(name: String, calories: String, protein: String, carbs: String, fat: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Please enter a meal name." }
        let kcal = Int(calories) ?? 0
        let p = Int(protein) ?? 0
        let c = Int(carbs) ?? 0
        let f = Int(fat) ?? 0
        if kcal <= 0 { return "Calories must be greater than 0." }
        if p < 0 || c < 0 || f < 0 { return "Macros cannot be negative." }
        return nil
    }

    func summary(for range: NutritionTimeRange) -> NutritionSummary {
        appState.nutritionSummary(for: range)
    }

    func meals(for range: NutritionTimeRange) -> [MealItem] {
        appState.meals(for: range)
    }

    func groupedMeals(for range: NutritionTimeRange) -> [(date: Date, meals: [MealItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: meals(for: range)) { meal in
            calendar.startOfDay(for: meal.loggedAt)
        }
        return grouped
            .map { (date: $0.key, meals: $0.value.sorted { $0.loggedAt > $1.loggedAt }) }
            .sorted { $0.date > $1.date }
    }

    func deleteMeal(id: UUID) {
        appState.deleteMeal(id: id)
    }

    func restoreMeal(_ meal: MealItem) {
        appState.restoreMeal(meal)
    }

    func trend(window: NutritionTrendWindow) -> [NutritionTrendPoint] {
        appState.nutritionTrend(window: window)
    }

    func startVoiceTranscription(
        onText: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard appState.voicePermissionStatus == .granted else {
            onError("Enable voice permissions first.")
            return
        }
        voiceTranscriber.start(onText: onText, onError: onError)
    }

    func stopVoiceTranscription() {
        voiceTranscriber.stop()
    }

    func parseMealInput(_ input: String) -> (name: String, calories: String, protein: String, carbs: String, fat: String)? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        let calories = firstNonEmptyMatch(
            patterns: [
                "(\\d+)\\s*(kcal|calories|calorie)",
                "kcal\\s*(\\d+)",
                "(\\d+)\\s*大卡"
            ],
            in: lower
        ) ?? ""
        let protein = firstNonEmptyMatch(
            patterns: [
                "(\\d+)\\s*(g\\s*)?(protein)",
                "p\\s*[:：]?\\s*(\\d+)",
                "蛋白\\s*(\\d+)"
            ],
            in: lower
        ) ?? ""
        let carbs = firstNonEmptyMatch(
            patterns: [
                "(\\d+)\\s*(g\\s*)?(carb|carbs)",
                "c\\s*[:：]?\\s*(\\d+)",
                "碳水\\s*(\\d+)"
            ],
            in: lower
        ) ?? ""
        let fat = firstNonEmptyMatch(
            patterns: [
                "(\\d+)\\s*(g\\s*)?(fat)",
                "f\\s*[:：]?\\s*(\\d+)",
                "脂肪\\s*(\\d+)"
            ],
            in: lower
        ) ?? ""
        let name = lower.components(separatedBy: CharacterSet.decimalDigits).first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return (
            name.isEmpty ? "Voice Meal" : name.capitalized,
            calories,
            protein,
            carbs,
            fat
        )
    }

    func mealAssistantReply(for input: String) async -> (reply: String, parsed: (name: String, calories: String, protein: String, carbs: String, fat: String)?) {
        if useLiveBackend {
            do {
                let remote = try await appState.requestMealAssistant(input: input)
                if remote.parsed != nil {
                    return (remote.reply + " (Remote)", remote.parsed)
                }
            } catch {
                // Fall through to local parser; UI remains unchanged.
            }
        }

        guard let parsed = parseMealInput(input) else {
            return (Self.assistantParseFailureHint, nil)
        }
        let modeSuffix = useLiveBackend ? " (Local fallback)" : " (Local)"
        let reply = "Parsed meal: \(parsed.name), kcal \(parsed.calories.isEmpty ? "-" : parsed.calories), P \(parsed.protein.isEmpty ? "-" : parsed.protein)g, C \(parsed.carbs.isEmpty ? "-" : parsed.carbs)g, F \(parsed.fat.isEmpty ? "-" : parsed.fat)g. Tap \"Add to Meal\" to save.\(modeSuffix)"
        return (reply, parsed)
    }

    func saveParsedMeal(_ parsed: (name: String, calories: String, protein: String, carbs: String, fat: String)) {
        guard validateManualMeal(
            name: parsed.name,
            calories: parsed.calories,
            protein: parsed.protein,
            carbs: parsed.carbs,
            fat: parsed.fat
        ) == nil else { return }
        addManualMeal(
            name: parsed.name,
            calories: Int(parsed.calories) ?? 0,
            protein: Int(parsed.protein) ?? 0,
            carbs: Int(parsed.carbs) ?? 0,
            fat: Int(parsed.fat) ?? 0
        )
    }

    private static let assistantParseFailureHint = "I could not parse your input. Please include meal name plus calories/protein/carbs/fat, for example: chicken rice 620 calories 45 protein 70 carbs 15 fat."
}

private func firstMatch(_ pattern: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else { return nil }
    guard let captureRange = Range(match.range(at: 1), in: text) else { return nil }
    return String(text[captureRange])
}

private func firstNonEmptyMatch(patterns: [String], in text: String) -> String? {
    for pattern in patterns {
        if let value = firstMatch(pattern, in: text), !value.isEmpty {
            return value
        }
    }
    return nil
}

@MainActor
final class CoachViewModel: ObservableObject {
    private let appState: AppState
    init(appState: AppState) { self.appState = appState }
    var advice: CoachAdvice { appState.coachAdvice }

    func refreshCoach() {
        Task {
            await appState.refreshCoachAdvice()
        }
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    private let appState: AppState
    init(appState: AppState) { self.appState = appState }

    var healthStatus: HealthAuthorizationStatus { appState.healthStatus }
    var latestHealthSummary: String { appState.latestHealthSummary }
    var authMethod: String { appState.authMethod.isEmpty ? "unknown" : appState.authMethod }
    var userProfile: UserProfile? { appState.userProfile }
    var primaryGoal: PrimaryGoal { appState.userProfile?.primaryGoal ?? .muscleGain }
    var dailyWorkoutGoalKcal: Int { appState.userProfile?.dailyWorkoutGoalKcal ?? 300 }
    var subscriptionPlan: SubscriptionPlan { appState.subscriptionPlan }
    var scanQuotaText: String { appState.remainingMealScansText() }
    var useLiveBackend: Bool { appState.useLiveBackend }
    var backendStatusMessage: String { appState.backendStatusMessage }

    func requestHealthPermission() async {
        await appState.requestHealthAccess()
    }

    func setPlan(_ plan: SubscriptionPlan) {
        appState.setSubscriptionPlan(plan)
    }

    func syncStoreKitSubscription() async {
        await appState.syncSubscriptionWithStoreKit()
    }

    func setLiveBackend(_ enabled: Bool) {
        appState.setLiveBackendEnabled(enabled)
    }

    func signOut() {
        appState.signOut()
    }

    func setPrimaryGoal(_ goal: PrimaryGoal) {
        appState.updatePrimaryGoal(goal)
    }

    func setDailyWorkoutGoal(_ goal: Int) {
        appState.updateDailyWorkoutGoal(goal)
    }

    func updateProfileBasics(age: Int, sex: Sex, heightCm: Double, weightKg: Double) {
        appState.updateProfileBasics(age: age, sex: sex, heightCm: heightCm, weightKg: weightKg)
    }

    func updatePreferredUnits(heightUnit: HeightUnit, weightUnit: WeightUnit) {
        appState.updatePreferredUnits(heightUnit: heightUnit, weightUnit: weightUnit)
    }

    func exportLocalData() throws -> URL {
        try appState.exportLocalData()
    }

    func resetLocalTrackingData() {
        appState.resetLocalTrackingData()
    }

}

@MainActor
final class AIAssistantViewModel: ObservableObject {
    typealias MealDraft = (name: String, calories: Int, protein: Int, carbs: Int, fat: Int)
    typealias WorkoutDraft = (exercise: String, sets: Int, reps: Int, weight: Double, rpe: Int)
    private let appState: AppState
    private let geminiService = GeminiAssistantService()
    private let voiceTranscriber = VoiceTranscriptionService()

    init(appState: AppState) { self.appState = appState }

    var remainingCount: Int { appState.aiAssistantRemainingCount }
    var dailyLimit: Int { appState.aiAssistantDailyLimit }
    var quotaText: String { "\(remainingCount)/\(dailyLimit) remaining today" }
    var isQuotaExceeded: Bool { remainingCount <= 0 }
    var voicePermissionStatus: VoicePermissionStatus { appState.voicePermissionStatus }

    func requestVoiceAccess() async {
        await appState.requestVoiceInputAccess()
    }

    func startVoiceTranscription(
        onText: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard appState.voicePermissionStatus == .granted else {
            onError("Enable voice permissions first.")
            return
        }
        voiceTranscriber.start(onText: onText, onError: onError)
    }

    func stopVoiceTranscription() {
        voiceTranscriber.stop()
    }

    func send(text: String, imageData: Data?) async -> (reply: String, pendingMeal: MealDraft?, pendingWorkout: WorkoutDraft?) {
        guard appState.consumeAIAssistantQuota() else {
            return ("Daily quota reached. Free: 5/day, Pro: 100/day.", nil, nil)
        }

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = normalizedText.lowercased()
        let looksLikeWorkoutLog = isWorkoutLoggingRequest(lower)
        let looksLikeMealLog = isMealLoggingRequest(lower, hasImage: imageData != nil)

        // Production-friendly path: when "Live backend" is enabled, parse workout/meal via backend
        // so the app doesn't need a client-side Gemini API key.
        if appState.useLiveBackend {
            do {
                if looksLikeWorkoutLog {
                    let remote = try await appState.requestWorkoutAssistant(input: text)
                    if let parsed = remote.parsed,
                       let sets = Int(parsed.sets), sets > 0,
                       let reps = Int(parsed.reps), reps > 0 {
                        let draft: WorkoutDraft = (
                            exercise: parsed.exercise,
                            sets: sets,
                            reps: reps,
                            weight: Double(parsed.weight) ?? 0,
                            rpe: Int(parsed.rpe) ?? 0
                        )
                        return ("\(remote.reply)\nPlease confirm this workout to add it to Training.", nil, draft)
                    }
                }

                if looksLikeMealLog {
                    let remote = try await appState.requestMealAssistant(input: text, imageData: imageData)
                    if let parsed = remote.parsed,
                       let calories = Int(parsed.calories), calories > 0 {
                        let draft: MealDraft = (
                            name: parsed.name,
                            calories: calories,
                            protein: Int(parsed.protein) ?? 0,
                            carbs: Int(parsed.carbs) ?? 0,
                            fat: Int(parsed.fat) ?? 0
                        )
                        return (remote.reply, draft, nil)
                    }
                    // If meal endpoint returned a natural-language reply but no structured macros,
                    // avoid an extra chat roundtrip (which increases latency) and surface its reply.
                    let mealReply = remote.reply.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !mealReply.isEmpty {
                        return (mealReply, nil, nil)
                    }
                }

                let chatReply = try await appState.requestChatAssistant(input: text)
                return (chatReply, nil, nil)
            } catch {
                if AppConfig.isReleaseMode {
                    return ("AI service is temporarily unavailable. Please try again shortly.", nil, nil)
                }
                // Development fallback only.
            }
        }

        if AppConfig.isReleaseMode {
            return fallbackReplyAndApply(text: text, hasImage: imageData != nil)
        }

        if let output = try? await geminiService.analyze(text: text, imageData: imageData) {
            switch output.intent {
            case .workout:
                if looksLikeWorkoutLog, let workout = output.workout {
                    let draft: WorkoutDraft = (
                        exercise: workout.exercise,
                        sets: workout.sets,
                        reps: workout.reps,
                        weight: workout.weight,
                        rpe: workout.rpe
                    )
                    return ("\(output.reply)\nPlease confirm this workout to add it to Training.", nil, draft)
                }
            case .nutrition:
                if looksLikeMealLog, let meal = output.meal {
                    return (output.reply, meal, nil)
                }
            case .chat:
                return (output.reply, nil, nil)
            }
            return (output.reply, nil, nil)
        }

        // Local fallback if AI services are unavailable.
        return fallbackReplyAndApply(text: text, hasImage: imageData != nil)
    }

    func confirmMeal(_ draft: MealDraft) {
        appState.addManualMeal(
            name: draft.name,
            calories: draft.calories,
            protein: draft.protein,
            carbs: draft.carbs,
            fat: draft.fat
        )
    }

    func confirmWorkout(_ draft: WorkoutDraft) {
        appState.addWorkout(input: WorkoutInput(
            exerciseName: draft.exercise,
            sets: draft.sets,
            reps: draft.reps,
            weight: draft.weight,
            rpe: draft.rpe
        ))
    }

    private func fallbackReplyAndApply(text: String, hasImage: Bool) -> (reply: String, pendingMeal: MealDraft?, pendingWorkout: WorkoutDraft?) {
        let lower = text.lowercased()
        let looksLikeWorkout = isWorkoutLoggingRequest(lower)
        let looksLikeMeal = isMealLoggingRequest(lower, hasImage: hasImage)

        if looksLikeWorkout {
            let sets = Int(firstMatch("(\\d+)\\s*(set|sets)", in: lower) ?? "0") ?? 0
            let reps = Int(firstMatch("(\\d+)\\s*(rep|reps)", in: lower) ?? "0") ?? 0
            let weight = Double(firstMatch("(\\d+(?:\\.\\d+)?)\\s*(kg|lb|lbs)", in: lower) ?? "0") ?? 0
            let rpe = Int(firstMatch("rpe\\s*(\\d+)", in: lower) ?? "7") ?? 7
            let name = lower.components(separatedBy: CharacterSet.decimalDigits).first?.trimmingCharacters(in: .whitespacesAndNewlines)
            if sets > 0, reps > 0 {
                let draft: WorkoutDraft = (
                    exercise: (name?.isEmpty == false ? name! : "Workout").capitalized,
                    sets: sets,
                    reps: reps,
                    weight: weight,
                    rpe: rpe
                )
                return ("Parsed workout locally.\nPlease confirm this workout to add it to Training.", nil, draft)
            }
        }

        if looksLikeMeal {
            let calories = Int(firstMatch("(\\d+)\\s*(kcal|calories|calorie)", in: lower) ?? "480") ?? 480
            let protein = Int(firstMatch("(\\d+)\\s*(g\\s*)?(protein)", in: lower) ?? "30") ?? 30
            let carbs = Int(firstMatch("(\\d+)\\s*(g\\s*)?(carb|carbs)", in: lower) ?? "45") ?? 45
            let fat = Int(firstMatch("(\\d+)\\s*(g\\s*)?(fat)", in: lower) ?? "15") ?? 15
            let name = lower.components(separatedBy: CharacterSet.decimalDigits).first?.trimmingCharacters(in: .whitespacesAndNewlines)
            let draft: MealDraft = (
                (name?.isEmpty == false ? name! : "Scanned Meal").capitalized,
                calories,
                protein,
                carbs,
                fat
            )
            return ("Parsed nutrition locally and added to Nutrition.", draft, nil)
        }

        return (
            "",
            nil,
            nil
        )
    }

    private func isWorkoutLoggingRequest(_ lower: String) -> Bool {
        let keywords = [" set", " sets", " rep", " reps", " rpe", "bench", "squat", "deadlift", "press", "row", "pull up", "workout"]
        let loggingWords = ["log", "add", "did", "done", "trained", "training", "lifted"]
        let hasWorkoutKeyword = keywords.contains { lower.contains($0) }
        let hasLoggingWord = loggingWords.contains { lower.contains($0) }
        return hasWorkoutKeyword && (hasLoggingWord || lower.contains("kg") || lower.contains("lb") || lower.contains("lbs"))
    }

    private func isMealLoggingRequest(_ lower: String, hasImage: Bool) -> Bool {
        if hasImage { return true }
        let mealContextWords = ["ate", "had", "meal", "food", "breakfast", "lunch", "dinner", "snack", "log", "add"]
        let nutritionFieldWords = ["calories", "calorie", "kcal", "protein", "carb", "carbs", "fat"]
        let foodEntityWords = ["chicken", "beef", "pork", "fish", "salad", "rice", "burger", "subway", "in-n-out", "in n out", "roast", "sandwich", "pizza"]
        let questionWords = ["how many", "should i", "what should", "recommend", "suggest"]
        let hasMealContext = mealContextWords.contains { lower.contains($0) }
        let nutritionHits = nutritionFieldWords.filter { lower.contains($0) }.count
        let mentionsFoodEntity = foodEntityWords.contains { lower.contains($0) }
        let isQuestionOnly = questionWords.contains { lower.contains($0) } && !hasMealContext
        // Nutrition questions about a specific food should still route to meal parsing.
        if nutritionHits >= 1 && mentionsFoodEntity { return true }
        if isQuestionOnly { return false }
        return hasMealContext && (nutritionHits >= 1 || mentionsFoodEntity)
    }
}
