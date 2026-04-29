//
//  ContentView.swift
//  fitnesscoach
//
//  Created by Jeremy Liu on 4/27/26.
//

import SwiftUI
import AuthenticationServices

struct ContentView: View {
    @ObservedObject private var appState: AppState
    @StateObject private var viewModelStore: AppViewModelStore
    @State private var selectedTab: AppTab = .recovery

    init(appState: AppState) {
        self._appState = ObservedObject(wrappedValue: appState)
        _viewModelStore = StateObject(wrappedValue: AppViewModelStore(appState: appState))
    }

    var body: some View {
        Group {
            if !appState.isAuthenticated {
                AuthGatewayView(appState: appState)
            } else if !appState.hasCompletedOnboarding {
                OnboardingProfileView(appState: appState)
            } else {
                VStack(spacing: 0) {
                    Group {
                        switch selectedTab {
                        case .recovery:
                            HomeView(
                                viewModel: viewModelStore.homeViewModel,
                                assistantViewModel: viewModelStore.aiAssistantViewModel
                            )
                        case .workout:
                            WorkoutView(
                                viewModel: viewModelStore.workoutViewModel,
                                assistantViewModel: viewModelStore.aiAssistantViewModel
                            )
                        case .nutrition:
                            NutritionView(
                                viewModel: viewModelStore.nutritionViewModel,
                                assistantViewModel: viewModelStore.aiAssistantViewModel
                            )
                        case .profile:
                            ProfileView(viewModel: viewModelStore.profileViewModel)
                        }
                    }

                    AppTabBar(selectedTab: $selectedTab)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.bgBottom.opacity(0.95), AppTheme.bgMiddle.opacity(0.95)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(AppTheme.accent)
        .animation(AppTheme.standardAnimation, value: appState.isAuthenticated)
        .animation(AppTheme.standardAnimation, value: appState.hasCompletedOnboarding)
    }
}

private struct AuthGatewayView: View {
    @ObservedObject var appState: AppState
    @State private var authMessage = ""
    @State private var authInProgressProvider: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.02, green: 0.07, blue: 0.16),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                Circle()
                    .fill(Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.28))
                    .frame(width: 260, height: 260)
                    .blur(radius: 32)
                    .offset(x: -120, y: -260)
                Circle()
                    .fill(Color(red: 0.65, green: 1.0, blue: 0.0).opacity(0.24))
                    .frame(width: 300, height: 300)
                    .blur(radius: 34)
                    .offset(x: 140, y: -160)

                VStack(spacing: 0) {
                    Spacer(minLength: 26)

                    VStack(spacing: 14) {
                        Image("AppCover")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 108, height: 108)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                            )
                        Text("FitX")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Neural flow powered fitness recovery.")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 20)

                    VStack(spacing: 12) {
                        HStack(spacing: 18) {
                            googleIconButton
                            appleIconButton
                        }
                        Text("Continue with Google or Apple")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.7))
                        if !authMessage.isEmpty {
                            Text(authMessage)
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 62)
                }
            }
            .navigationTitle("FitX")
        }
    }

    private var googleIconButton: some View {
        Button {
            startGoogleAuth()
        } label: {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.98), Color.white.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .overlay(
                    GoogleGMark()
                        .frame(width: 42, height: 42)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 0.9)
                )
        }
        .buttonStyle(.plain)
        .opacity(authInProgressProvider == nil || authInProgressProvider == "google" ? 1 : 0.55)
        .disabled(authInProgressProvider != nil)
        .accessibilityLabel(authInProgressProvider == "google" ? "Opening Google sign in" : "Sign in with Google")
    }

    private var appleIconButton: some View {
        Group {
            if AppConfig.isReleaseMode {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 88, height: 88)
                        .overlay(
                            Image(systemName: "applelogo")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.88))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.9)
                        )

                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .opacity(0.015)
                }
            } else {
                Button {
                    appState.signInWithProvider("apple-dev")
                    authMessage = "开发模式：Apple 登录走本地调试直通。上架前请切换到 release 模式并启用正式能力。"
                } label: {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 88, height: 88)
                        .overlay(
                            Image(systemName: "applelogo")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.88))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.9)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(authInProgressProvider == nil || authInProgressProvider == "apple" ? 1 : 0.55)
        .allowsHitTesting(authInProgressProvider == nil)
        .accessibilityLabel(authInProgressProvider == "apple" ? "Opening Apple sign in" : "Sign in with Apple")
    }

    private func startGoogleAuth() {
        authInProgressProvider = "google"
        authMessage = ""
        Task {
            defer { authInProgressProvider = nil }
            do {
                try await appState.signInWithOAuthProvider(.google)
                authMessage = ""
            } catch {
                // Keep auth flow usable in development when OAuth keys are not configured yet.
                if let oauthError = error as? SocialOAuthError {
                    switch oauthError {
                    case .missingClientID, .invalidRedirectURI:
                        appState.signInWithProvider("google")
                        authMessage = "Google OAuth not configured yet. Signed in using local fallback."
                    case .authorizationCancelled:
                        authMessage = "Google sign-in was cancelled."
                    case .missingAuthorizationCode:
                        authMessage = "Google sign-in did not return a valid authorization code."
                    }
                } else {
                    authMessage = "Google sign-in failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        authInProgressProvider = "apple"
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authMessage = "Apple authorization did not return a valid credential."
                authInProgressProvider = nil
                return
            }
            let email = credential.email
            appState.signInWithApple(userID: credential.user, email: email)
            authMessage = ""
            authInProgressProvider = nil
        case .failure(let error):
            authMessage = "Apple sign-in failed: \(error.localizedDescription)"
            authInProgressProvider = nil
        }
    }
}

private struct GoogleGMark: View {
    var body: some View {
        ZStack {
            Circle().trim(from: 0.00, to: 0.24).stroke(Color(red: 0.92, green: 0.30, blue: 0.22), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            Circle().trim(from: 0.24, to: 0.50).stroke(Color(red: 0.98, green: 0.73, blue: 0.06), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            Circle().trim(from: 0.50, to: 0.74).stroke(Color(red: 0.24, green: 0.73, blue: 0.35), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            Circle().trim(from: 0.74, to: 1.00).stroke(Color(red: 0.16, green: 0.48, blue: 0.96), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            Rectangle()
                .fill(Color.white)
                .frame(width: 18, height: 16)
                .offset(x: 10, y: 2)
            Rectangle()
                .fill(Color(red: 0.16, green: 0.48, blue: 0.96))
                .frame(width: 15, height: 8)
                .offset(x: 7, y: 2)
        }
        .rotationEffect(.degrees(-14))
    }
}

private struct OnboardingProfileView: View {
    @ObservedObject var appState: AppState
    @State private var ageText = "25"
    @State private var sex: Sex = .male
    @State private var heightUnit: HeightUnit = .ftIn
    @State private var weightUnit: WeightUnit = .lbs
    @State private var heightCmText = "175"
    @State private var feetText = "5"
    @State private var inchesText = "9"
    @State private var weightKgText = "70"
    @State private var weightLbsText = "154"
    @State private var primaryGoal: PrimaryGoal = .muscleGain
    @State private var activityLevel: ActivityLevel = .medium
    @State private var calorieDeltaText = "700"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    BrandHeader(title: "Profile Setup", subtitle: "Used to estimate BMR and recovery")

                    AppSectionCard(title: "Basic Info") {
                        TextField("Age", text: $ageText)
                            .glassTextField()
                        Picker("Sex", selection: $sex) {
                            ForEach(Sex.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    AppSectionCard(title: "Body Metrics") {
                        Picker("Height Unit", selection: $heightUnit) {
                            Text("cm").tag(HeightUnit.cm)
                            Text("ft/in").tag(HeightUnit.ftIn)
                        }
                        .pickerStyle(.segmented)

                        if heightUnit == .cm {
                            TextField("Height (cm)", text: $heightCmText)
                                .glassTextField()
                        } else {
                            HStack {
                                TextField("ft", text: $feetText).glassTextField()
                                TextField("in", text: $inchesText).glassTextField()
                            }
                        }

                        Picker("Weight Unit", selection: $weightUnit) {
                            Text("kg").tag(WeightUnit.kg)
                            Text("lbs").tag(WeightUnit.lbs)
                        }
                        .pickerStyle(.segmented)

                        if weightUnit == .kg {
                            TextField("Weight (kg)", text: $weightKgText)
                                .glassTextField()
                        } else {
                            TextField("Weight (lbs)", text: $weightLbsText)
                                .glassTextField()
                        }
                    }

                    AppSectionCard(title: "Primary Goal") {
                        Picker("Goal", selection: $primaryGoal) {
                            ForEach(PrimaryGoal.allCases) { goal in
                                Text(goal.rawValue).tag(goal)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(primaryGoal == .muscleGain
                             ? "Recommended calorie surplus: +500 to +1000 kcal/day."
                             : "Recommended calorie deficit: -500 to -1000 kcal/day.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    AppSectionCard(title: "Activity Level") {
                        Picker("Activity", selection: $activityLevel) {
                            ForEach(ActivityLevel.allCases) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("Used to estimate your baseline expenditure before training/rest-day adjustments.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    AppSectionCard(title: "Daily Calorie Delta Goal") {
                        TextField("Calorie delta (e.g. -500 for deficit, +500 for surplus)", text: $calorieDeltaText)
                            .glassTextField()
                        Text("This value is used as your target daily calorie gap.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    if let preview = profilePreview {
                        AppSectionCard(title: "Estimated Metrics") {
                            MetricRow(title: "BMI (auto)", value: String(format: "%.1f", preview.bmi))
                            MetricRow(title: "BMR", value: "\(Int(preview.bmr.rounded())) kcal/day")
                            Text("BMR is your baseline energy burn used in daily expenditure estimates.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Button("Continue") {
                        guard let profile = profilePreview else { return }
                        appState.completeOnboarding(profile: profile)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(profilePreview == nil)
                }
                .padding()
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
            }
            .appBackground()
            .navigationTitle("Onboarding")
        }
    }

    private var profilePreview: UserProfile? {
        guard let age = Int(ageText), age > 0 else { return nil }
        let heightCm: Double
        switch heightUnit {
        case .cm:
            guard let cm = Double(heightCmText), cm > 0 else { return nil }
            heightCm = cm
        case .ftIn:
            guard let ft = Double(feetText), let inch = Double(inchesText), ft >= 0, inch >= 0 else { return nil }
            heightCm = ((ft * 12.0) + inch) * 2.54
            if heightCm <= 0 { return nil }
        }

        let weightKg: Double
        switch weightUnit {
        case .kg:
            guard let kg = Double(weightKgText), kg > 0 else { return nil }
            weightKg = kg
        case .lbs:
            guard let lbs = Double(weightLbsText), lbs > 0 else { return nil }
            weightKg = lbs * 0.45359237
        }

        guard let calorieDelta = Int(calorieDeltaText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }

        return UserProfile(
            age: age,
            sex: sex,
            heightCm: heightCm,
            weightKg: weightKg,
            preferredHeightUnit: heightUnit,
            preferredWeightUnit: weightUnit,
            primaryGoal: primaryGoal,
            activityLevel: activityLevel,
            calorieDeltaGoalKcal: calorieDelta,
            dailyWorkoutGoalKcal: 300
        )
    }
}

@MainActor
final class AppViewModelStore: ObservableObject {
    let homeViewModel: HomeViewModel
    let aiAssistantViewModel: AIAssistantViewModel
    let recoveryViewModel: RecoveryViewModel
    let workoutViewModel: WorkoutViewModel
    let nutritionViewModel: NutritionViewModel
    let coachViewModel: CoachViewModel
    let profileViewModel: ProfileViewModel

    init(appState: AppState) {
        self.homeViewModel = HomeViewModel(appState: appState)
        self.aiAssistantViewModel = AIAssistantViewModel(appState: appState)
        self.recoveryViewModel = RecoveryViewModel(appState: appState)
        self.workoutViewModel = WorkoutViewModel(appState: appState)
        self.nutritionViewModel = NutritionViewModel(appState: appState)
        self.coachViewModel = CoachViewModel(appState: appState)
        self.profileViewModel = ProfileViewModel(appState: appState)
    }
}

enum AppTab: String, CaseIterable {
    case recovery
    case workout
    case nutrition
    case profile

    var title: String {
        switch self {
        case .recovery: return "Recovery"
        case .workout: return "Training"
        case .nutrition: return "Nutrition"
        case .profile: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .recovery: return "waveform.path.ecg"
        case .workout: return "figure.run.circle.fill"
        case .nutrition: return "fork.knife.circle.fill"
        case .profile: return "gearshape.fill"
        }
    }
}

struct AppTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                            .fill(
                                isSelected
                                ? LinearGradient(
                                    colors: [AppTheme.accent.opacity(0.28), AppTheme.accent2.opacity(0.26)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                            .stroke(isSelected ? AppTheme.accent.opacity(0.85) : AppTheme.softStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(appState: AppState())
    }
}
