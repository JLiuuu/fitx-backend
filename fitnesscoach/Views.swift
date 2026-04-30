import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif
#if os(iOS) && canImport(UIKit)
import UIKit
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(Charts)
import Charts
#endif

private struct AIChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var assistantViewModel: AIAssistantViewModel
    @State private var heatmapFront = true
    @State private var showUnifiedAssistant = false

    var body: some View {
        let dashboard = viewModel.dashboard
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    ScreenHeader(title: "Today", subtitle: "Train smarter every day") {
                        AICapsuleButton {
                            showUnifiedAssistant = true
                        }
                    }

                    AppSectionCard(title: "Recovery Score", subtitle: "Today") {
                        HStack(alignment: .lastTextBaseline) {
                            Text("\(dashboard.readinessScore)%")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.iconGradient)
                                .contentTransition(.numericText())
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.heart.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(AppTheme.iconGradient)
                                    Text(viewModel.todayAvgHeartRate > 0 ? "\(viewModel.todayAvgHeartRate)" : "--")
                                        .font(.headline.bold())
                                        .foregroundStyle(AppTheme.iconGradient)
                                }
                                Text("bpm")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        Text(dashboard.statusText)
                            .secondaryHelperText()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))

                    MacroRingsCard(
                        protein: (viewModel.proteinConsumed, viewModel.proteinGoal, viewModel.proteinProgress),
                        carbs: (viewModel.carbsConsumed, viewModel.carbsGoal, viewModel.carbsProgress),
                        fat: (viewModel.fatConsumed, viewModel.fatGoal, viewModel.fatProgress),
                        totalCaloriesText: viewModel.nutritionTotalCaloriesText
                    )

                    AppSectionCard(title: "Today's Expenditure", subtitle: "BMR + Active Energy") {
                        HStack {
                            Text("BMR")
                                .secondaryHelperText()
                            Spacer()
                            Text("\(viewModel.bmrKcal) kcal")
                                .font(.headline.monospacedDigit())
                        }
                        HStack {
                            Text("Active (Watch)")
                                .secondaryHelperText()
                            Spacer()
                            Text("\(viewModel.activeEnergyForExpenditure) kcal")
                                .font(.headline.monospacedDigit())
                        }
                        Divider().overlay(Color.white.opacity(AppTheme.dividerOpacity))
                        HStack {
                            Text("Total")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(viewModel.todayTotalExpenditureKcal) kcal")
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(AppTheme.iconGradient)
                        }
                    )

                    AppSectionCard(title: "Recovery Signals", subtitle: "Apple Watch key metrics") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                            signalChip(icon: "flame.fill", title: "Active kcal", value: "\(viewModel.todayActiveEnergyKcal)", range: "Typical 300-900")
                            signalChip(icon: "figure.walk", title: "Steps", value: "\(viewModel.todayStepCount)", range: "Typical 6k-12k")
                            signalChip(icon: "figure.walk.motion", title: "Distance", value: viewModel.todayDistanceKmText, range: "Typical 4-10 km")
                            signalChip(icon: "heart.text.square.fill", title: "HRV", value: viewModel.todayHRVms > 0 ? "\(viewModel.todayHRVms) ms" : "--", range: "Typical 30-90 ms")
                            signalChip(icon: "bed.double.fill", title: "Sleep", value: viewModel.todaySleepHoursText, range: "Goal 7.5-9.0 h")
                            signalChip(
                                icon: "waveform.path.ecg",
                                title: "HR Range",
                                value: viewModel.todayAvgHeartRate > 0 ? "L \(viewModel.todayMinHeartRate) / A \(viewModel.todayAvgHeartRate) / H \(viewModel.todayMaxHeartRate)" : "--",
                                range: "Avg target 55-95 bpm"
                            )
                        }
                        Text(viewModel.latestHealthSummary)
                            .tertiaryHelperText()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recovery Heatmap")
                                .font(.title3.bold())
                            Spacer()
                            Text(heatmapFront ? "Front" : "Back")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        ZStack {
                            RadialGradient(
                                colors: [
                                    AppTheme.accent2.opacity(0.16),
                                    AppTheme.accent.opacity(0.10),
                                    AppTheme.accent3.opacity(0.06),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 240
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))

                            MuscleHeatmapView(isFront: $heatmapFront, items: viewModel.recoveryItems)
                        }
                    }
                    .glassCard()
                    .transition(.opacity)

                    AppSectionCard(title: "AI Coach", subtitle: "Actionable daily guidance") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(viewModel.aiCoachNutritionLine)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Text(viewModel.aiCoachRestLine)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Text(viewModel.aiCoachTrainingLine)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
            }
            .appBackground()
            .navigationTitle("Today")
            #if os(iOS)
            .fullScreenCover(isPresented: $showUnifiedAssistant) {
                UnifiedAIAssistantSheet(viewModel: assistantViewModel, initialAutoPrompt: nil)
            }
            #else
            .sheet(isPresented: $showUnifiedAssistant) {
                UnifiedAIAssistantSheet(viewModel: assistantViewModel, initialAutoPrompt: nil)
            }
            #endif
        }
    }

    @ViewBuilder
    private func signalChip(icon: String, title: String, value: String, range: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.iconGradient)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
            Text(range)
                .font(.caption2)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct RecoveryView: View {
    @ObservedObject var viewModel: RecoveryViewModel
    @State private var heatmapFront = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    AppSectionCard(title: "Recovery Score", subtitle: "Today") {
                        HStack {
                            Text("\(viewModel.readinessScore)%")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                            Spacer()
                            Text(viewModel.lastWorkoutSummary)
                                .secondaryHelperText()
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    AppSectionCard(title: "Muscle Recovery Heatmap", subtitle: heatmapFront ? "Front" : "Back") {
                        MuscleHeatmapView(isFront: $heatmapFront, items: viewModel.items)
                    }
                    AppSectionCard(title: "AI Coach", subtitle: "3-line guidance") {
                        Text("1) Nutrition: prioritize protein and hydration after training.")
                            .font(.subheadline)
                        Text("2) Rest: avoid heavy loading on your highest-fatigue muscles.")
                            .font(.subheadline)
                        Text("3) Train: focus on recovered muscle groups with controlled volume.")
                            .font(.subheadline)
                    }
                    AppSectionCard(title: "Muscle Status", subtitle: "Recovery %") {
                        ForEach(viewModel.items) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(item.status.color)
                                    .frame(width: 9, height: 9)
                                Text(item.muscleName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(max(0, min(100, 100 - item.fatigueScore)))%")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(item.status.color)
                            }
                            if item.id != viewModel.items.last?.id {
                                Divider().overlay(Color.white.opacity(AppTheme.dividerOpacity))
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity)
            .appBackground()
            .navigationTitle("Recovery")
        }
    }
}

private struct UnifiedAIAssistantSheet: View {
    private enum PendingAssistantAction {
        case meal(AIAssistantViewModel.MealDraft)
        case workout(AIAssistantViewModel.WorkoutDraft)

        var prompt: String {
            switch self {
            case .meal:
                return "Add this to your Nutrition today?"
            case .workout:
                return "Add this to your Training today?"
            }
        }

        var addButtonTitle: String {
            switch self {
            case .meal:
                return "Add to Nutrition"
            case .workout:
                return "Add to Training"
            }
        }
    }

    private struct BinaryPrompt {
        enum Kind {
            case generatePlan(target: String)
            case addPlanToTraining(drafts: [AIAssistantViewModel.WorkoutDraft])
        }
        let prompt: String
        let yesTitle: String
        let noTitle: String
        let kind: Kind
    }

    private enum TrainingFlowState {
        case idle
        case awaitingTargetSelection
        case planReady(target: String, drafts: [AIAssistantViewModel.WorkoutDraft])
    }

    @ObservedObject var viewModel: AIAssistantViewModel
    let initialAutoPrompt: String?
    @Environment(\.dismiss) private var dismiss
    @State private var composerText = ""
    @State private var isListening = false
    @State private var isSending = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var cameraMessage = ""
    @State private var showCameraCaptureSheet = false
    @State private var pendingAssistantAction: PendingAssistantAction?
    @State private var pendingBinaryPrompt: BinaryPrompt?
    @State private var trainingFlowState: TrainingFlowState = .idle
    @State private var scrollAnchor = UUID()
    @State private var didAutoPrompt = false
    @State private var selectedPreviewImageData: Data?

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FitX AI")
                            .font(.headline)
                        Text("Chat to log workout or meal")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text(viewModel.quotaText)
                        .font(.caption2)
                        .foregroundStyle(viewModel.isQuotaExceeded ? .yellow : AppTheme.textSecondary)
                }
                .padding(.horizontal, 4)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.chatMessages) { message in
                                messageRow(message)
                            }
                            Color.clear
                                .frame(height: 1)
                                .id(scrollAnchor)
                        }
                    }
                    .textSelection(.enabled)
                    .onChange(of: viewModel.chatMessages.count) { _, _ in
                        withAnimation(AppTheme.standardAnimation) {
                            proxy.scrollTo(scrollAnchor, anchor: .bottom)
                        }
                    }
                }

                Spacer(minLength: 0)

                if !cameraMessage.isEmpty {
                    Text(cameraMessage)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let pendingAssistantAction {
                    HStack(spacing: 8) {
                        Text(pendingAssistantAction.prompt)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Button("Dismiss") {
                            self.pendingAssistantAction = nil
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.textSecondary)

                        Button(pendingAssistantAction.addButtonTitle) {
                            switch pendingAssistantAction {
                            case .meal(let draft):
                                viewModel.confirmMeal(draft)
                                viewModel.appendChatMessage(role: "assistant", text: "Added to Nutrition.")
                            case .workout(let draft):
                                viewModel.confirmWorkout(draft)
                                viewModel.appendChatMessage(role: "assistant", text: "Added to Training.")
                            }
                            self.pendingAssistantAction = nil
                        }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let pendingBinaryPrompt {
                    HStack(spacing: 8) {
                        Text(pendingBinaryPrompt.prompt)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Button(pendingBinaryPrompt.noTitle) {
                            self.pendingBinaryPrompt = nil
                            trainingFlowState = .idle
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.textSecondary)
                        Button(pendingBinaryPrompt.yesTitle) {
                            let prompt = pendingBinaryPrompt
                            self.pendingBinaryPrompt = nil
                            Task { @MainActor in
                                switch prompt.kind {
                                case .generatePlan(let target):
                                    isSending = true
                                    let reply = await viewModel.generateGymPlanText(for: target)
                                    viewModel.appendChatMessage(role: "assistant", text: reply)
                                    let drafts = viewModel.defaultPlanDrafts(for: target)
                                    trainingFlowState = .planReady(target: target, drafts: drafts)
                                    viewModel.appendChatMessage(role: "assistant", text: "How does this plan look? If you are OK with it, I can add it to today's Training.")
                                    pendingBinaryPrompt = BinaryPrompt(
                                        prompt: "Add this \(target) plan to today's Training data?",
                                        yesTitle: "Yes ✅",
                                        noTitle: "No ❌",
                                        kind: .addPlanToTraining(drafts: drafts)
                                    )
                                    isSending = false
                                case .addPlanToTraining(let drafts):
                                    viewModel.addWorkoutPlanDrafts(drafts)
                                    viewModel.appendChatMessage(role: "assistant", text: "Done. Added this plan to today's Training.")
                                    trainingFlowState = .idle
                                }
                            }
                        }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button {
                            cameraMessage = ""
                            composerText = "What should I train today?"
                            sendMessage()
                        } label: {
                            Text("🧠 What should I train today?")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.accent2, AppTheme.accent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .opacity(0.18)
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(AppTheme.iconGradient.opacity(0.45), lineWidth: 1)
                                )
                                .clipShape(Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                #if os(iOS)
                if let selectedImageData, let previewImage = UIImage(data: selectedImageData) {
                    HStack(spacing: 10) {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        Text("Ready")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Button {
                            self.selectedImageData = nil
                            cameraMessage = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)
                }
                #endif

                HStack(spacing: 8) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "photo")
                            .font(.headline)
                            .foregroundStyle(AppTheme.iconGradient)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            let granted = await requestCameraAccess()
                            if granted {
                                #if os(iOS)
                                showCameraCaptureSheet = true
                                cameraMessage = "Camera ready. Take a photo to attach."
                                #else
                                cameraMessage = "Camera is available only on iOS target. Use Gallery on this target."
                                #endif
                            } else {
                                cameraMessage = "Camera permission denied."
                            }
                        }
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.iconGradient)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        toggleMic()
                    } label: {
                        Image(systemName: isListening ? "mic.fill" : "mic")
                            .font(.headline)
                            .foregroundStyle(isListening ? Color.black : AppTheme.accent)
                            .padding(8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isListening ? AppTheme.accent : Color.white.opacity(0.08))
                            )
                            .symbolEffect(.pulse, options: .repeating, value: isListening)
                    }
                    .buttonStyle(.bordered)

                    TextField("Message", text: $composerText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule(style: .continuous))

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.iconGradient)
                            .padding(10)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSending || (composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if isSending {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Thinking...")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .appBackground()
            .navigationTitle("AI Assistant")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    selectedImageData = try? await newItem.loadTransferable(type: Data.self)
                    if selectedImageData != nil {
                        cameraMessage = ""
                    }
                }
            }
            .onAppear {
                guard !didAutoPrompt, let prompt = initialAutoPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !prompt.isEmpty else { return }
                didAutoPrompt = true
                composerText = prompt
                sendMessage()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .sheet(isPresented: $showCameraCaptureSheet) {
            CameraCaptureView { data in
                if let data {
                    selectedImageData = data
                    cameraMessage = ""
                } else {
                    cameraMessage = "No photo captured."
                }
            }
        }
        .sheet(isPresented: isImagePreviewPresented) {
            #if os(iOS)
            ZStack {
                Color.black.ignoresSafeArea()
                if let data = selectedPreviewImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            }
            #else
            EmptyView()
            #endif
        }
        #endif
    }

    private func sendMessage() {
        if isListening {
            viewModel.stopVoiceTranscription()
            isListening = false
            cameraMessage = "Voice capture stopped and message sent."
        }
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageToSend = selectedImageData
        if !text.isEmpty {
            viewModel.appendChatMessage(role: "user", text: text, imageData: imageToSend)
        } else if let imageToSend {
            viewModel.appendChatMessage(role: "user", text: "", imageData: imageToSend)
        }
        composerText = ""
        isSending = true
        let image = selectedImageData
        selectedImageData = nil
        selectedPhotoItem = nil
        Task { @MainActor in
            if image == nil {
                let lower = text.lowercased()
                if lower.contains("what should i train today") {
                    trainingFlowState = .awaitingTargetSelection
                    viewModel.appendChatMessage(role: "assistant", text: viewModel.trainingFocusSummaryMessage())
                    isSending = false
                    return
                }

                switch trainingFlowState {
                case .awaitingTargetSelection:
                    if let target = viewModel.detectTrainingTarget(from: text) {
                        pendingBinaryPrompt = BinaryPrompt(
                            prompt: "You chose \(target). Generate a detailed gym plan now?",
                            yesTitle: "Yes ✅",
                            noTitle: "No ❌",
                            kind: .generatePlan(target: target)
                        )
                        viewModel.appendChatMessage(role: "assistant", text: "Great choice: \(target). Do you want a detailed plan now?")
                    } else if !text.isEmpty {
                        viewModel.appendChatMessage(role: "assistant", text: "Please choose one area: chest, back, legs, shoulders, biceps, triceps, or abs.")
                    }
                    isSending = false
                    return
                case .planReady(let target, let drafts):
                    if viewModel.isAffirmative(text) {
                        pendingBinaryPrompt = BinaryPrompt(
                            prompt: "Add this \(target) plan to today's Training data?",
                            yesTitle: "Yes ✅",
                            noTitle: "No ❌",
                            kind: .addPlanToTraining(drafts: drafts)
                        )
                        isSending = false
                        return
                    }
                    if viewModel.wantsAlternatives(text) {
                        let alt = await viewModel.generateGymPlanText(for: target)
                        viewModel.appendChatMessage(role: "assistant", text: "Sure — here is an alternative plan:\n\(alt)")
                        isSending = false
                        return
                    }
                case .idle:
                    break
                }
            }

            let result = await viewModel.send(text: text, imageData: image)
            pendingAssistantAction = nil
            if let pending = result.pendingMeal {
                let reply = result.reply.trimmingCharacters(in: .whitespacesAndNewlines)
                if !reply.isEmpty {
                    viewModel.appendChatMessage(role: "assistant", text: reply)
                }
                pendingAssistantAction = .meal(pending)
            } else if let pendingWorkout = result.pendingWorkout {
                let reply = result.reply.trimmingCharacters(in: .whitespacesAndNewlines)
                if !reply.isEmpty {
                    viewModel.appendChatMessage(role: "assistant", text: reply)
                }
                pendingAssistantAction = .workout(pendingWorkout)
            } else {
                let reply = result.reply.trimmingCharacters(in: .whitespacesAndNewlines)
                if !reply.isEmpty {
                    viewModel.appendChatMessage(role: "assistant", text: reply)
                }
            }
            isSending = false
        }
    }

    private func toggleMic() {
        if isListening {
            viewModel.stopVoiceTranscription()
            isListening = false
            cameraMessage = "Voice capture stopped."
            return
        }
        Task {
            await viewModel.requestVoiceAccess()
            guard viewModel.voicePermissionStatus == .granted else {
                cameraMessage = "Microphone/Speech permission denied. Enable it in Settings."
                return
            }
            isListening = true
            cameraMessage = "Listening... speak now."
            viewModel.startVoiceTranscription { text in
                composerText = text
            } onError: { message in
                isListening = false
                cameraMessage = ""
            }
        }
    }

    private func requestCameraAccess() async -> Bool {
        #if canImport(AVFoundation)
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
        #else
        return false
        #endif
    }

    @ViewBuilder
    private func messageRow(_ message: AIAssistantViewModel.ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == "assistant" {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image("AppCover")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                    )
                messageBubble(message, isUser: false)
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                messageBubble(message, isUser: true)
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 24, height: 24)
                    .overlay(Image(systemName: "person.fill").font(.caption2))
            }
        }
    }

    private func messageBubble(_ message: AIAssistantViewModel.ChatMessage, isUser: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = message.imageData, let image = uiImage(from: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture { selectedPreviewImageData = imageData }
            }
            if !message.text.isEmpty {
                Text(message.text)
                    .foregroundStyle(isUser ? Color.black.opacity(0.9) : Color.white)
                    .contextMenu {
                        Button("Copy") { copyToPasteboard(message.text) }
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [AppTheme.accent2, AppTheme.accent],
                startPoint: .leading,
                endPoint: .trailing
            )
            .opacity(isUser ? 0.92 : 0.20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func uiImage(from data: Data) -> UIImage? {
        #if os(iOS)
        return UIImage(data: data)
        #else
        return nil
        #endif
    }

    private func copyToPasteboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #endif
    }

    private var isImagePreviewPresented: Binding<Bool> {
        Binding(
            get: { selectedPreviewImageData != nil },
            set: { if !$0 { selectedPreviewImageData = nil } }
        )
    }
}

#if os(iOS) && canImport(UIKit)
private struct CameraCaptureView: UIViewControllerRepresentable {
    let onComplete: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onComplete(nil)
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            let data = image?.jpegData(compressionQuality: 0.85)
            parent.onComplete(data)
            parent.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
#endif

private struct WorkoutAIChatSheet: View {
    @ObservedObject var viewModel: WorkoutViewModel
    let onApplyParsed: ((exercise: String, sets: String, reps: String, weight: String, rpe: String)) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [AIChatMessage] = [
        AIChatMessage(role: "assistant", text: "Describe your workout in text or voice, e.g. bench press 4 sets 8 reps 80 kg rpe 8.")
    ]
    @State private var composerText = ""
    @State private var isListening = false
    @State private var isSending = false
    @State private var parsedWorkout: (exercise: String, sets: String, reps: String, weight: String, rpe: String)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            HStack {
                                if message.role == "assistant" {
                                    Text(message.text)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Spacer()
                                } else {
                                    Spacer()
                                    Text(message.text)
                                        .padding(10)
                                        .background(AppTheme.accent.opacity(0.25))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Type workout message...", text: $composerText)
                        .glassTextField()
                    Button(isListening ? "Stop Mic" : "Mic") {
                        toggleMic()
                    }
                    .buttonStyle(.bordered)
                    Button("Send") {
                        sendMessage()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSending || composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if isSending {
                    Text("Processing your message...")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let parsedWorkout {
                    Button("Add to Workout") {
                        viewModel.saveParsedWorkout(parsedWorkout)
                        onApplyParsed(parsedWorkout)
                        dismiss()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }
            .padding()
            .navigationTitle("Workout Assistant")
        }
    }

    private func sendMessage() {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(.init(role: "user", text: text))
        composerText = ""
        isSending = true
        Task { @MainActor in
            let result = await viewModel.workoutAssistantReply(for: text)
            messages.append(.init(role: "assistant", text: result.reply))
            parsedWorkout = result.parsed
            isSending = false
        }
    }

    private func toggleMic() {
        if isListening {
            viewModel.stopVoiceTranscription()
            isListening = false
            return
        }
        isListening = true
        viewModel.startVoiceTranscription { text in
            composerText = text
        } onError: { message in
            messages.append(.init(role: "assistant", text: "Voice input error: \(message)"))
            isListening = false
        }
    }
}

private struct MealAIChatSheet: View {
    @ObservedObject var viewModel: NutritionViewModel
    let onApplyParsed: ((name: String, calories: String, protein: String, carbs: String, fat: String)) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [AIChatMessage] = [
        AIChatMessage(role: "assistant", text: "Describe meal nutrition in text or voice, e.g. chicken rice 620 calories 45 protein 70 carbs 15 fat.")
    ]
    @State private var composerText = ""
    @State private var isListening = false
    @State private var isSending = false
    @State private var parsedMeal: (name: String, calories: String, protein: String, carbs: String, fat: String)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            HStack {
                                if message.role == "assistant" {
                                    Text(message.text)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Spacer()
                                } else {
                                    Spacer()
                                    Text(message.text)
                                        .padding(10)
                                        .background(AppTheme.accent.opacity(0.25))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Type meal message...", text: $composerText)
                        .glassTextField()
                    Button(isListening ? "Stop Mic" : "Mic") {
                        toggleMic()
                    }
                    .buttonStyle(.bordered)
                    Button("Send") {
                        sendMessage()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSending || composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if isSending {
                    Text("Processing your message...")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let parsedMeal {
                    HStack(spacing: 8) {
                        Button("Apply to Form") {
                            onApplyParsed(parsedMeal)
                        }
                        .buttonStyle(.bordered)
                        Button("Add to Meal") {
                            viewModel.saveParsedMeal(parsedMeal)
                            dismiss()
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                }
            }
            .padding()
            .navigationTitle("Meal Assistant")
        }
    }

    private func sendMessage() {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(.init(role: "user", text: text))
        composerText = ""
        isSending = true
        Task { @MainActor in
            let result = await viewModel.mealAssistantReply(for: text)
            messages.append(.init(role: "assistant", text: result.reply))
            parsedMeal = result.parsed
            isSending = false
        }
    }

    private func toggleMic() {
        if isListening {
            viewModel.stopVoiceTranscription()
            isListening = false
            return
        }
        isListening = true
        viewModel.startVoiceTranscription { text in
            composerText = text
        } onError: { message in
            messages.append(.init(role: "assistant", text: "Voice input error: \(message)"))
            isListening = false
        }
    }
}

struct WorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @ObservedObject var assistantViewModel: AIAssistantViewModel
    @State private var exerciseName = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var rpe = ""
    @State private var saveMessage = ""
    @State private var formPulse = false
    @State private var pendingDeleteWorkout: WorkoutLogItem?
    @State private var recentlyDeletedWorkout: WorkoutLogItem?
    @State private var showUnifiedAssistant = false
    @State private var trendWindow: NutritionTrendWindow = .sevenDays

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.sectionSpacing) {
                    ScreenHeader(title: "Training", subtitle: "Strength, expenditure, and trends") {
                        AICapsuleButton {
                            showUnifiedAssistant = true
                        }
                    }
                    AppSectionCard(title: "Vibe") {
                        let vibe = viewModel.vibePercent
                        Text("\(vibe)%")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(vibeColor(vibe))
                        Text(viewModel.vibeSuggestion)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    TrainingRingsCard(
                        workoutBurn: viewModel.trainingBurnKcal,
                        workoutGoal: viewModel.totalBurnedKcal,
                        workoutProgress: min(1.0, Double(viewModel.trainingBurnKcal) / Double(max(1, viewModel.totalBurnedKcal))),
                        workoutDurationMinutes: viewModel.trainingDurationMinutes,
                        workoutDurationGoalMinutes: viewModel.trainingDurationTargetMinutes,
                        workoutDurationProgress: viewModel.trainingDurationProgress
                    )

                    AppSectionCard(title: "Workout Trend", subtitle: "Calories over time") {
                        Picker("Trend Window", selection: $trendWindow) {
                            ForEach(NutritionTrendWindow.allCases) { window in
                                Text(window.rawValue).tag(window)
                            }
                        }
                        .pickerStyle(.segmented)
                        WorkoutTrendChart(data: viewModel.workoutTrend(window: trendWindow))
                    }

                    AppSectionCard(title: "Add Workout", subtitle: "Manual input with optional AI assist") {
                        TextField("Exercise", text: $exerciseName)
                            .glassTextField()
                        HStack(spacing: 10) {
                            TextField("Sets", text: $sets).glassTextField()
                            TextField("Reps", text: $reps).glassTextField()
                        }
                        HStack(spacing: 10) {
                            TextField(viewModel.weightFieldPlaceholder, text: $weight)
                                .glassTextField()
                            TextField("RPE (1–10)", text: $rpe).glassTextField()
                        }
                        Text("RPE = how hard the set felt. Enter a whole number from 1 (very easy) to 10 (max effort, no clean reps left).")
                            .secondaryHelperText()
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Save Workout") {
                            if let validationError = viewModel.validateWorkoutInput(
                                exerciseName: exerciseName,
                                sets: sets,
                                reps: reps,
                                weight: weight,
                                rpe: rpe
                            ) {
                                saveMessage = validationError
                                return
                            }
                            viewModel.saveWorkout(
                                exerciseName: exerciseName,
                                sets: sets,
                                reps: reps,
                                weight: weight,
                                rpe: rpe
                            )
                            saveMessage = "Workout saved and recovery recalculated."
                            exerciseName = ""
                            sets = ""
                            reps = ""
                            weight = ""
                            rpe = ""
                            formPulse.toggle()
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .scaleEffect(formPulse ? 1.01 : 1)
                        .animation(AppTheme.fastAnimation, value: formPulse)

                        if !saveMessage.isEmpty {
                            StatusMessageText(
                                message: saveMessage,
                                tone: saveMessage.contains("saved") ? .success : .warning
                            )
                        }
                    }

                    if viewModel.workoutLogs.isEmpty {
                        EmptyStateCard(
                            icon: "figure.strengthtraining.traditional",
                            title: "No workouts logged yet",
                            message: "Add your first workout to estimate expenditure and update fatigue."
                        )
                    } else {
                        AppSectionCard(title: "Workout History", subtitle: "Tap trash to remove") {
                            ForEach(viewModel.groupedWorkoutLogs, id: \.date) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(group.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.textTertiary)
                                    ForEach(group.logs) { log in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(log.exerciseName)
                                                    .font(.headline)
                                                Spacer()
                                                Text("\(log.estimatedCalories) kcal")
                                                    .font(.subheadline)
                                                    .foregroundStyle(AppTheme.accent)
                                                Button(role: .destructive) {
                                                    pendingDeleteWorkout = log
                                                } label: {
                                                    Image(systemName: "trash")
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            Text(viewModel.workoutHistoryWeightSubtitle(for: log))
                                                .secondaryHelperText()
                                            Text(log.loggedAt.formatted(date: .omitted, time: .shortened))
                                                .tertiaryHelperText()
                                        }
                                        .padding(.vertical, 4)
                                        if log.id != group.logs.last?.id {
                                            Divider().overlay(Color.white.opacity(AppTheme.dividerOpacity))
                                        }
                                    }
                                }
                                if group.date != viewModel.groupedWorkoutLogs.last?.date {
                                    Divider().overlay(Color.white.opacity(AppTheme.dividerOpacity))
                                }
                            }
                            if let recentlyDeletedWorkout {
                                HStack {
                                    Text("Workout deleted.")
                                        .secondaryHelperText()
                                    Spacer()
                                    Button("Undo") {
                                        viewModel.restoreWorkout(recentlyDeletedWorkout)
                                        self.recentlyDeletedWorkout = nil
                                    }
                                    .font(.caption.weight(.semibold))
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
            }
            .appBackground()
            .navigationTitle("Training")
            #if os(iOS)
            .fullScreenCover(isPresented: $showUnifiedAssistant) {
                UnifiedAIAssistantSheet(viewModel: assistantViewModel, initialAutoPrompt: nil)
            }
            #else
            .sheet(isPresented: $showUnifiedAssistant) {
                UnifiedAIAssistantSheet(viewModel: assistantViewModel, initialAutoPrompt: nil)
            }
            #endif
            .alert(
                "Delete this workout?",
                isPresented: Binding(
                    get: { pendingDeleteWorkout != nil },
                    set: { if !$0 { pendingDeleteWorkout = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let pendingDeleteWorkout {
                        viewModel.deleteWorkout(id: pendingDeleteWorkout.id)
                        recentlyDeletedWorkout = pendingDeleteWorkout
                        self.pendingDeleteWorkout = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteWorkout = nil
                }
            } message: {
                Text("This will remove the workout from history.")
            }
        }
    }

    private func vibeColor(_ value: Int) -> Color {
        switch value {
        case 80...: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }
}

struct NutritionView: View {
    @ObservedObject var viewModel: NutritionViewModel
    @ObservedObject var assistantViewModel: AIAssistantViewModel
    @State private var selectedRange: NutritionTimeRange = .day
    @State private var mealName = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var manualSaveMessage = ""
    @State private var trendWindow: NutritionTrendWindow = .sevenDays
    @State private var pendingDeleteMeal: MealItem?
    @State private var recentlyDeletedMeal: MealItem?
    @State private var showUnifiedAssistant = false
    @State private var assistantAutoPrompt: String?

    var body: some View {
        let todaySummary = viewModel.summary(for: .day)
        let groupedMeals = viewModel.groupedMeals(for: selectedRange)
        let trendData = viewModel.trend(window: trendWindow)
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.sectionSpacing) {
                    ScreenHeader(title: "Nutrition", subtitle: "Macros, meals, and intake quality") {
                        AICapsuleButton {
                            assistantAutoPrompt = nil
                            showUnifiedAssistant = true
                        }
                    }

                    MacroProgressBarsCard(
                        protein: (todaySummary.protein, max(1, viewModel.proteinGoal)),
                        carbs: (todaySummary.carbs, max(1, viewModel.carbsGoal)),
                        fat: (todaySummary.fat, max(1, viewModel.fatGoal))
                    )

                    AppSectionCard(title: "Need Food Suggestions?") {
                        Text("Ask AI what to eat based on your current macro gap and calorie target.")
                            .secondaryHelperText()
                        Button {
                            let proteinLeft = max(0, viewModel.proteinGoal - todaySummary.protein)
                            let carbsLeft = max(0, viewModel.carbsGoal - todaySummary.carbs)
                            let fatLeft = max(0, viewModel.fatGoal - todaySummary.fat)
                            let caloriesLeft = max(0, viewModel.calorieGoal - todaySummary.calories)
                            let goalText = viewModel.primaryGoal == .fatLoss ? "fat loss" : "muscle gain"
                            assistantAutoPrompt = """
                            Please act as my nutrition coach and create today's meal plan.
                            My goal is \(goalText).
                            Remaining target for today: \(caloriesLeft) kcal, protein \(proteinLeft)g, carbs \(carbsLeft)g, fat \(fatLeft)g.
                            Give me a practical full-day meal recommendation (breakfast/lunch/dinner/snacks), approximate macros for each meal, and one easy grocery list.
                            """
                            showUnifiedAssistant = true
                        } label: {
                            Label("Ask AI for Food Suggestions", systemImage: "brain.head.profile")
                                .foregroundStyle(AppTheme.iconGradient)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }

                    AppSectionCard(title: "Manual Meal Entry", subtitle: "Free & Pro") {
                        TextField("Meal name", text: $mealName)
                            .glassTextField()
                        HStack(spacing: 10) {
                            TextField("Calories", text: $calories)
                                .glassTextField()
                            TextField("Protein (g)", text: $protein)
                                .glassTextField()
                        }
                        HStack(spacing: 10) {
                            TextField("Carbs (g)", text: $carbs)
                                .glassTextField()
                            TextField("Fat (g)", text: $fat)
                                .glassTextField()
                        }
                        Button("Add Manual Meal") {
                            if let validationError = viewModel.validateManualMeal(
                                name: mealName,
                                calories: calories,
                                protein: protein,
                                carbs: carbs,
                                fat: fat
                            ) {
                                manualSaveMessage = validationError
                                return
                            }
                            let trimmed = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let kcal = Int(calories) ?? 0
                            let p = Int(protein) ?? 0
                            let c = Int(carbs) ?? 0
                            let f = Int(fat) ?? 0
                            viewModel.addManualMeal(name: trimmed, calories: kcal, protein: p, carbs: c, fat: f)
                            mealName = ""
                            calories = ""
                            protein = ""
                            carbs = ""
                            fat = ""
                            manualSaveMessage = "Meal added."
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        if !manualSaveMessage.isEmpty {
                            StatusMessageText(
                                message: manualSaveMessage,
                                tone: manualSaveMessage.contains("added") ? .success : .warning
                            )
                        }
                    }

                    AppSectionCard(title: "Nutrition Trend", subtitle: "Calories + Macros") {
                        Picker("Trend Window", selection: $trendWindow) {
                            ForEach(NutritionTrendWindow.allCases) { window in
                                Text(window.rawValue).tag(window)
                            }
                        }
                        .pickerStyle(.segmented)
                        NutritionTrendChart(data: trendData)
                    }

                    if groupedMeals.isEmpty {
                        EmptyStateCard(
                            icon: "fork.knife.circle",
                            title: "No meals logged yet",
                            message: "Add your first manual meal or use Pro meal scan."
                        )
                    } else {
                        AppSectionCard(title: "Today's Meal", subtitle: selectedRange.rawValue) {
                            ForEach(groupedMeals, id: \.date) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(group.date.formatted(date: .abbreviated, time: .omitted)) • \(group.meals.count) meals")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                    ForEach(group.meals) { meal in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(meal.name)
                                                    .font(.headline)
                                                Spacer()
                                                Button(role: .destructive) {
                                                    pendingDeleteMeal = meal
                                                } label: {
                                                    Image(systemName: "trash")
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            Text("kcal \(meal.calories), P \(meal.protein)g, C \(meal.carbs)g, F \(meal.fat)g")
                                                .font(.subheadline)
                                                .foregroundStyle(AppTheme.textSecondary)
                                            Text("\(meal.source.rawValue) • \(meal.loggedAt.formatted(date: .omitted, time: .shortened))")
                                                .tertiaryHelperText()
                                            Text("Confidence: \(Int(meal.confidence * 100))%")
                                                .secondaryHelperText()
                                            if meal.needsConfirmation {
                                                Text("Needs user confirmation")
                                                    .font(.caption)
                                                    .foregroundStyle(.yellow)
                                                ForEach(meal.questions, id: \.self) { question in
                                                    Text("• \(question)")
                                                        .tertiaryHelperText()
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        if meal.id != group.meals.last?.id {
                                            Divider().overlay(Color.white.opacity(AppTheme.dividerOpacity))
                                        }
                                    }
                                    if group.date != groupedMeals.last?.date {
                                        Divider().overlay(Color.white.opacity(AppTheme.dividerOpacity))
                                            .padding(.vertical, 4)
                                    }
                                }
                            }
                            if let recentlyDeletedMeal {
                                HStack {
                                    Text("Meal deleted.")
                                        .secondaryHelperText()
                                    Spacer()
                                    Button("Undo") {
                                        viewModel.restoreMeal(recentlyDeletedMeal)
                                        self.recentlyDeletedMeal = nil
                                    }
                                    .font(.caption.weight(.semibold))
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
            }
            .appBackground()
            .navigationTitle("Nutrition")
            .alert(
                "Delete this meal?",
                isPresented: Binding(
                    get: { pendingDeleteMeal != nil },
                    set: { if !$0 { pendingDeleteMeal = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let pendingDeleteMeal {
                        viewModel.deleteMeal(id: pendingDeleteMeal.id)
                        recentlyDeletedMeal = pendingDeleteMeal
                        self.pendingDeleteMeal = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteMeal = nil
                }
            } message: {
                Text("This will remove the meal and update daily totals.")
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showUnifiedAssistant) {
                UnifiedAIAssistantSheet(viewModel: assistantViewModel, initialAutoPrompt: assistantAutoPrompt)
            }
            #else
            .sheet(isPresented: $showUnifiedAssistant) {
                UnifiedAIAssistantSheet(viewModel: assistantViewModel, initialAutoPrompt: assistantAutoPrompt)
            }
            #endif
        }
    }
}

struct NutritionTrendChart: View {
    let data: [NutritionTrendPoint]
    @State private var selectedPoint: NutritionTrendPoint?
    private var unifiedTrendGradient: LinearGradient {
        LinearGradient(
            colors: [AppTheme.accent2, AppTheme.accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        #if canImport(Charts)
        Chart {
            ForEach(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Calories", point.calories)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(unifiedTrendGradient)
                .lineStyle(.init(lineWidth: 2.5))

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Protein", point.protein)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(unifiedTrendGradient)
                .lineStyle(.init(lineWidth: 1.8))

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Carbs", point.carbs)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(unifiedTrendGradient)
                .lineStyle(.init(lineWidth: 1.8))

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Fat", point.fat)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(unifiedTrendGradient)
                .lineStyle(.init(lineWidth: 1.6))
            }

            if let selectedPoint {
                RuleMark(x: .value("Selected Date", selectedPoint.date))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 3]))
                PointMark(
                    x: .value("Selected Date", selectedPoint.date),
                    y: .value("Selected Calories", selectedPoint.calories)
                )
                .foregroundStyle(AppTheme.accent)
                .symbolSize(50)
                .annotation(position: .top, alignment: .leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedPoint.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2.weight(.semibold))
                        Text("Kcal \(selectedPoint.calories)")
                        Text("P \(selectedPoint.protein)g  C \(selectedPoint.carbs)g  F \(selectedPoint.fat)g")
                    }
                    .font(.caption2)
                    .padding(8)
                    .background(Color.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: .init(lineWidth: 0.6))
                    .foregroundStyle(Color.white.opacity(0.15))
                AxisValueLabel()
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, data.count / 4))) { value in
                AxisGridLine(stroke: .init(lineWidth: 0.4))
                    .foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(height: 210)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let plotRect = geo[plotFrame]
                                let x = value.location.x - plotRect.origin.x
                                guard x >= 0, x <= plotRect.size.width,
                                      let date: Date = proxy.value(atX: x) else { return }
                                selectedPoint = data.min {
                                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                }
                            }
                    )
            }
        }
        #else
        Text("Charts is unavailable on this target.")
            .secondaryHelperText()
            .frame(maxWidth: .infinity, minHeight: 120)
        #endif
    }
}

struct WorkoutTrendChart: View {
    let data: [WorkoutTrendPoint]
    @State private var selectedPoint: WorkoutTrendPoint?

    var body: some View {
        #if canImport(Charts)
        Chart {
            ForEach(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Calories", point.calories)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accent2, AppTheme.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(.init(lineWidth: 2.4))
            }

            if let selectedPoint {
                RuleMark(x: .value("Selected Date", selectedPoint.date))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 3]))
                PointMark(
                    x: .value("Selected Date", selectedPoint.date),
                    y: .value("Selected Calories", selectedPoint.calories)
                )
                .foregroundStyle(AppTheme.accent)
                .symbolSize(50)
                .annotation(position: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedPoint.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2.weight(.semibold))
                        Text("\(selectedPoint.calories) kcal")
                            .font(.caption2)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: .init(lineWidth: 0.6))
                    .foregroundStyle(Color.white.opacity(0.15))
                AxisValueLabel()
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, data.count / 4))) { _ in
                AxisGridLine(stroke: .init(lineWidth: 0.4))
                    .foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(height: 190)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let plotRect = geo[plotFrame]
                                let x = value.location.x - plotRect.origin.x
                                guard x >= 0, x <= plotRect.size.width,
                                      let date: Date = proxy.value(atX: x) else { return }
                                selectedPoint = data.min {
                                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                }
                            }
                    )
            }
        }
        #else
        Text("Charts is unavailable on this target.")
            .secondaryHelperText()
            .frame(maxWidth: .infinity, minHeight: 120)
        #endif
    }
}

struct CoachView: View {
    @ObservedObject var viewModel: CoachViewModel

    var body: some View {
        let advice = viewModel.advice
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GroupBox("Readiness Score") {
                        Text("\(advice.readinessScore)%")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .glassCard()
                    AdviceCard(title: "Training", content: advice.training, color: AppTheme.accent2)
                    AdviceCard(title: "Nutrition", content: advice.nutrition, color: AppTheme.accent)
                    AdviceCard(title: "Recovery", content: advice.recovery, color: .green)
                    AdviceCard(title: "Warning", content: advice.warning, color: AppTheme.warning)
                    AdviceCard(title: "Missing Data", content: advice.missingData, color: .gray)

                    Button("Refresh AI Advice") {
                        viewModel.refreshCoach()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .symbolEffect(.pulse, value: advice.readinessScore)
                }
                .padding()
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
            }
            .appBackground()
            .navigationTitle("AI Coach")
        }
    }
}

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var requesting = false
    @State private var syncingSubscription = false
    @State private var ageText = ""
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var feetText = ""
    @State private var inchesText = ""
    @State private var weightLbsText = ""
    @State private var heightUnit: HeightUnit = .cm
    @State private var weightUnit: WeightUnit = .kg
    @State private var selectedSex: Sex = .male
    @State private var profileSaveMessage = ""
    @State private var dailyWorkoutGoalValue = 300
    @State private var workoutGoalSaveMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.sectionSpacing) {
                    ScreenHeader(title: "Settings", subtitle: "Account, subscription, health, and privacy")

                    AppSectionCard(title: "Account", subtitle: "Authentication and profile") {
                        MetricRow(title: "Sign In Method", value: viewModel.authMethod.capitalized)
                        if let profile = viewModel.userProfile {
                            Button(heightUnit == .cm ? "Switch to ft/in + lbs" : "Switch to cm + kg") {
                                if heightUnit == .cm {
                                    heightUnit = .ftIn
                                    weightUnit = .lbs
                                } else {
                                    heightUnit = .cm
                                    weightUnit = .kg
                                }
                            }
                            .buttonStyle(.bordered)
                            TextField("Age", text: $ageText)
                                .glassTextField()
                            Picker("Sex", selection: $selectedSex) {
                                ForEach(Sex.allCases) { sex in
                                    Text(sex.rawValue).tag(sex)
                                }
                            }
                            .pickerStyle(.segmented)
                            if heightUnit == .cm {
                                TextField("Height (cm)", text: $heightText)
                                    .glassTextField()
                            } else {
                                HStack {
                                    TextField("Height (ft)", text: $feetText)
                                        .glassTextField()
                                    TextField("Height (in)", text: $inchesText)
                                        .glassTextField()
                                }
                            }
                            if weightUnit == .kg {
                                TextField("Weight (kg)", text: $weightText)
                                    .glassTextField()
                            } else {
                                TextField("Weight (lbs)", text: $weightLbsText)
                                    .glassTextField()
                            }
                            Button("Save Account Info") {
                                let parsedHeightCm: Double?
                                if heightUnit == .cm {
                                    parsedHeightCm = Double(heightText.trimmingCharacters(in: .whitespacesAndNewlines))
                                } else {
                                    let ft = Double(feetText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
                                    let inch = Double(inchesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
                                    parsedHeightCm = (ft >= 0 && inch >= 0) ? ((ft * 12.0 + inch) * 2.54) : nil
                                }
                                let parsedWeightKg: Double?
                                if weightUnit == .kg {
                                    parsedWeightKg = Double(weightText.trimmingCharacters(in: .whitespacesAndNewlines))
                                } else {
                                    let lbs = Double(weightLbsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
                                    parsedWeightKg = lbs > 0 ? (lbs * 0.45359237) : nil
                                }
                                guard
                                    let age = Int(ageText.trimmingCharacters(in: .whitespacesAndNewlines)),
                                    let height = parsedHeightCm,
                                    let weight = parsedWeightKg
                                else {
                                    profileSaveMessage = "Please enter valid age, height, and weight."
                                    return
                                }
                                viewModel.updateProfileBasics(age: age, sex: selectedSex, heightCm: height, weightKg: weight)
                                viewModel.updatePreferredUnits(heightUnit: heightUnit, weightUnit: weightUnit)
                                profileSaveMessage = "Account info updated."
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            if !profileSaveMessage.isEmpty {
                                StatusMessageText(
                                    message: profileSaveMessage,
                                    tone: profileSaveMessage.contains("updated") ? .success : .warning
                                )
                            }
                        } else {
                            Text("Profile setup is not completed.")
                                .secondaryHelperText()
                        }
                    }

                    AppSectionCard(title: "Goal & Targets", subtitle: "Primary goal affects calories and macros") {
                        Picker(
                            "Primary Goal",
                            selection: Binding(
                                get: { viewModel.primaryGoal },
                                set: { viewModel.setPrimaryGoal($0) }
                            )
                        ) {
                            ForEach(PrimaryGoal.allCases) { goal in
                                Text(goal.rawValue).tag(goal)
                            }
                        }
                        .pickerStyle(.segmented)
                        Stepper(
                            value: $dailyWorkoutGoalValue,
                            in: 80...1500,
                            step: 20
                        ) {
                            Text("Daily Workout Goal: \(dailyWorkoutGoalValue) kcal")
                        }
                        Button("Save Daily Workout Goal") {
                            viewModel.setDailyWorkoutGoal(dailyWorkoutGoalValue)
                            workoutGoalSaveMessage = "Daily workout goal updated."
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        if !workoutGoalSaveMessage.isEmpty {
                            StatusMessageText(message: workoutGoalSaveMessage, tone: .success)
                        }
                    }

                    AppSectionCard(title: "Subscription", subtitle: "Free vs Pro capabilities") {
                        Picker("Plan", selection: Binding(
                            get: { viewModel.subscriptionPlan },
                            set: { viewModel.setPlan($0) }
                        )) {
                            Text("Free").tag(SubscriptionPlan.free)
                            Text("Pro").tag(SubscriptionPlan.pro)
                        }
                        .pickerStyle(.segmented)

                        Text("Scan Quota: \(viewModel.scanQuotaText)")
                        Button(syncingSubscription ? "Syncing StoreKit..." : "Sync Subscription from StoreKit") {
                            Task {
                                syncingSubscription = true
                                await viewModel.syncStoreKitSubscription()
                                syncingSubscription = false
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(syncingSubscription)
                    }

                    AppSectionCard(title: "Health Data Access", subtitle: "Recovery signal inputs from Apple Health") {
                        Button(requesting ? "Requesting..." : "Authorize Health Data") {
                            Task {
                                requesting = true
                                await viewModel.requestHealthPermission()
                                requesting = false
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(requesting)

                        Text("Status: \(viewModel.healthStatus.rawValue)")
                        Text(viewModel.latestHealthSummary)
                            .secondaryHelperText()
                        #if os(iOS) && canImport(UIKit)
                        if viewModel.healthStatus == .denied {
                            Button("Open iOS Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            Text("Go to Settings > Privacy & Security > Health > FitX, then allow permissions.")
                                .secondaryHelperText()
                        }
                        #endif
                        Text("Recovery insights are estimates and not medical advice.")
                            .secondaryHelperText()
                    }

                    AppSectionCard(title: "AI Service", subtitle: "Choose online AI processing mode") {
                        Toggle(
                            "Enable Online AI",
                            isOn: Binding(
                                get: { viewModel.useLiveBackend },
                                set: { viewModel.setLiveBackend($0) }
                            )
                        )
                        Text(viewModel.backendStatusMessage)
                            .secondaryHelperText()
                        Text("If disabled or unavailable, FitX uses local fallback parsing for workout and meal logging.")
                            .tertiaryHelperText()
                    }

                    Button {
                        viewModel.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
                .padding()
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
            }
            .appBackground()
            .navigationTitle("Settings")
            .onAppear {
                if let profile = viewModel.userProfile {
                    ageText = "\(profile.age)"
                    heightText = String(Int(profile.heightCm.rounded()))
                    weightText = String(Int(profile.weightKg.rounded()))
                    let totalInches = profile.heightCm / 2.54
                    let ft = Int(totalInches / 12.0)
                    let inch = Int((totalInches - Double(ft * 12)).rounded())
                    feetText = "\(max(0, ft))"
                    inchesText = "\(max(0, inch))"
                    weightLbsText = String(Int((profile.weightKg / 0.45359237).rounded()))
                    heightUnit = profile.preferredHeightUnit
                    weightUnit = profile.preferredWeightUnit
                    selectedSex = profile.sex
                    dailyWorkoutGoalValue = profile.dailyWorkoutGoalKcal
                }
            }
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }
}

struct AdviceCard: View {
    let title: String
    let content: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.headline)
            }
            Text(content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(2)
        }
        .glassCard()
    }
}
