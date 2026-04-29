import SwiftUI

struct AppSectionCard<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            content
        }
        .glassCard()
    }
}

struct BrandHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image("AppCover")
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
    }
}

struct AICapsuleButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("AI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .clipShape(Capsule(style: .continuous))
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.iconGradient)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ScreenHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let trailing: Trailing

    init(title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    init(title: String, subtitle: String) where Trailing == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.trailing = EmptyView()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            trailing
        }
    }
}

enum StatusTone {
    case success
    case warning
}

struct StatusMessageText: View {
    let message: String
    let tone: StatusTone

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(tone == .success ? Color.green : AppTheme.warning)
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.iconGradient)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard()
    }
}

struct StatChip: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius))
    }
}

struct FitnessProgressRing: View {
    let progress: Double
    let gradientColors: [Color]
    let lineWidth: CGFloat
    let trackOpacity: Double
    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, animatedProgress)))
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            animatedProgress = 0
            withAnimation(AppTheme.standardAnimation) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(AppTheme.standardAnimation) {
                animatedProgress = newValue
            }
        }
    }
}

struct CaloriesRingCard: View {
    let workoutBurn: Int
    let workoutGoal: Int
    let workoutProgress: Double
    let bmr: Int
    let workoutDurationMinutes: Int
    let workoutDurationGoalMinutes: Int
    let workoutDurationProgress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout")
                .font(.title3.bold())
            HStack(spacing: 16) {
                ZStack {
                    FitnessProgressRing(
                        progress: workoutProgress,
                        gradientColors: AppTheme.progressGradientColors,
                        lineWidth: 14,
                        trackOpacity: 0.05
                    )
                        .frame(width: 102, height: 102)
                    VStack(spacing: 2) {
                        Text("\(workoutBurn)")
                            .font(.title2.bold())
                            .monospacedDigit()
                            .lineLimit(1)
                        Text("kcal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current/Target")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(workoutBurn)/\(workoutGoal)")
                            .font(.title2.bold())
                            .monospacedDigit()
                        Text("kcal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("BMR")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 6)
                        Text("\(bmr)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                        Text("kcal/day")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .glassCard()
    }
}

struct MacroRingsCard: View {
    let protein: (current: Int, goal: Int, progress: Double)
    let carbs: (current: Int, goal: Int, progress: Double)
    let fat: (current: Int, goal: Int, progress: Double)
    let calorieDeltaText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nutrition")
                .font(.title3.bold())
            HStack(spacing: 16) {
                ZStack {
                    FitnessProgressRing(
                        // Outside -> inside: Protein, Carbs, Fat
                        progress: protein.progress,
                        gradientColors: [AppTheme.lightBlue, AppTheme.accent2],
                        lineWidth: 10,
                        trackOpacity: 0.05
                    )
                        .frame(width: 122, height: 122)
                    FitnessProgressRing(
                        progress: carbs.progress,
                        gradientColors: [AppTheme.carbGreenHighlight, AppTheme.accent],
                        lineWidth: 10,
                        trackOpacity: 0.05
                    )
                        .frame(width: 96, height: 96)
                    FitnessProgressRing(
                        progress: fat.progress,
                        gradientColors: [AppTheme.lightGreen, AppTheme.accent],
                        lineWidth: 10,
                        trackOpacity: 0.05
                    )
                        .frame(width: 70, height: 70)
                }
                VStack(alignment: .leading, spacing: 5) {
                    macroLine(label: "Protein", current: protein.current, goal: protein.goal)
                    macroLine(label: "Carbs", current: carbs.current, goal: carbs.goal)
                    macroLine(label: "Fat", current: fat.current, goal: fat.goal)
                    Text(calorieDeltaText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
        }
        .glassCard()
    }

    private func macroLine(label: String, current: Int, goal: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(current)/\(goal)")
                    .font(.title2.bold())
                    .monospacedDigit()
                Text("g")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct TrainingRingsCard: View {
    let workoutBurn: Int
    let workoutGoal: Int
    let workoutProgress: Double
    let workoutDurationMinutes: Int?
    let workoutDurationGoalMinutes: Int
    let workoutDurationProgress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Overview")
                .font(.title3.bold())
            HStack(spacing: 18) {
                ringBlock(
                    title: "Kcal",
                    value: "\(workoutBurn)",
                    unit: "/\(workoutGoal)",
                    progress: workoutProgress,
                    tint: AppTheme.accent
                )
                ringBlock(
                    title: "Duration",
                    value: workoutDurationMinutes.map(String.init) ?? "N/A",
                    unit: workoutDurationMinutes == nil ? "" : "/\(workoutDurationGoalMinutes)m",
                    progress: workoutDurationProgress ?? 0,
                    tint: workoutDurationMinutes == nil ? Color.white.opacity(0.18) : Color(red: 0.38, green: 0.72, blue: 1.0)
                )
            }
        }
        .glassCard()
    }

    private func ringBlock(title: String, value: String, unit: String, progress: Double, tint: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                FitnessProgressRing(
                    progress: progress,
                    gradientColors: [tint.opacity(0.45), tint, tint.opacity(0.9)],
                    lineWidth: 12,
                    trackOpacity: 0.12
                )
                    .frame(width: 124, height: 124)
                VStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(unit)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MacroProgressBarsCard: View {
    let protein: (current: Int, goal: Int)
    let carbs: (current: Int, goal: Int)
    let fat: (current: Int, goal: Int)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macro Progress")
                .font(.headline)
            macroRow(title: "Protein", value: protein.current, goal: protein.goal)
            macroRow(title: "Carbs", value: carbs.current, goal: carbs.goal)
            macroRow(title: "Fat", value: fat.current, goal: fat.goal)
        }
        .glassCard()
    }

    private func macroRow(title: String, value: Int, goal: Int) -> some View {
        let progress = min(1.0, Double(value) / Double(max(1, goal)))
        let gradientColors: [Color]
        switch title {
        case "Protein":
            gradientColors = [AppTheme.lightBlue, AppTheme.accent2]
        case "Carbs":
            gradientColors = [AppTheme.carbGreenHighlight, AppTheme.accent]
        default:
            gradientColors = [AppTheme.lightGreen, AppTheme.accent]
        }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(value)/\(goal)")
                        .font(.title2.bold())
                        .monospacedDigit()
                    Text("g")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            GradientProgressBar(
                progress: progress,
                gradientColors: gradientColors,
                height: 8
            )
        }
    }
}

struct GradientProgressBar: View {
    let progress: Double
    let gradientColors: [Color]
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            let p = max(0, min(1, progress))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * p, height: height)
            }
        }
        .frame(height: height)
    }
}

struct SuggestedFoodsCard: View {
    let foods: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested Foods")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(foods, id: \.self) { food in
                    Text(food)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .glassCard()
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .frame(minHeight: AppTheme.primaryButtonHeight)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous)
                            .fill(Color.black.opacity(0.80))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous)
                    .stroke(AppTheme.iconGradient, lineWidth: 1.5)
                    .shadow(color: AppTheme.accent.opacity(0.30), radius: 5)
            )
            .foregroundStyle(Color.white.opacity(0.96))
            .shadow(color: Color.black.opacity(0.42), radius: 10, x: 0, y: 4)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AppTheme.fastAnimation, value: configuration.isPressed)
    }
}

struct GlassTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 42)
            .background(Color(red: 0.08, green: 0.16, blue: 0.21).opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.textFieldCornerRadius)
                    .stroke(AppTheme.softStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.textFieldCornerRadius, style: .continuous))
    }
}

struct MuscleHeatmapView: View {
    @Binding var isFront: Bool
    let items: [MuscleRecoveryItem]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(isFront ? "Front Body" : "Back Body")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Tap body to flip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ZStack {
                GeometryReader { proxy in
                    let contentRect = CGRect(
                        x: 6,
                        y: 8,
                        width: max(0, proxy.size.width - 12),
                        height: max(0, proxy.size.height - 16)
                    )
                    let imageRect = fittedRect(in: contentRect, aspectRatio: bodyImageAspectRatio)
                    ZStack {
                        Image(isFront ? "BodyFront" : "BodyBack")
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageRect.width, height: imageRect.height)
                            .position(x: imageRect.midX, y: imageRect.midY)

                        ForEach(maskLayers(forFront: isFront)) { layer in
                            let level = fatigue(for: layer.catalogMuscle)
                            let tint = recoveryColor(for: recoveryPercent(fromFatigue: level)).opacity(0.52)
                            muscleMaskOverlay(
                                asset: layer.assetName,
                                imageRect: imageRect,
                                tint: tint
                            )
                        }
                    }
                }
                .frame(height: 420)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(AppTheme.standardAnimation) {
                    isFront.toggle()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(sideCatalogNames, id: \.self) { name in
                    HStack(spacing: 10) {
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("Recovery \(recoveryPercent(for: name))%")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(recoveryColor(for: recoveryPercent(for: name)))
                    }
                }
            }
        }
    }

    private var sideCatalogNames: [String] {
        isFront ? MuscleCatalog.frontGroups : MuscleCatalog.backGroups
    }

    private func maskLayers(forFront: Bool) -> [HeatmapMaskLayer] {
        forFront ? Self.frontMaskLayers : Self.backMaskLayers
    }

    private func fatigue(for muscleName: String) -> Int {
        items.first { $0.muscleName.lowercased() == muscleName.lowercased() }?.fatigueScore ?? 0
    }

    private func recoveryPercent(for muscleName: String) -> Int {
        max(0, min(100, 100 - fatigue(for: muscleName)))
    }

    private func recoveryPercent(fromFatigue fatigue: Int) -> Int {
        max(0, min(100, 100 - fatigue))
    }

    private func recoveryColor(for recoveryPercent: Int) -> Color {
        let normalized = Double(max(0, min(100, recoveryPercent))) / 100.0
        // 0% recovery -> red, 50% -> yellow, 100% -> green.
        return Color(
            hue: normalized * 0.33,
            saturation: 0.90,
            brightness: 0.98
        )
    }

    private var bodyImageAspectRatio: CGFloat { 682.0 / 1024.0 }

    private func fittedRect(in rect: CGRect, aspectRatio: CGFloat) -> CGRect {
        guard rect.width > 0, rect.height > 0 else { return .zero }
        let containerRatio = rect.width / rect.height
        if containerRatio > aspectRatio {
            let height = rect.height
            let width = height * aspectRatio
            return CGRect(
                x: rect.minX + (rect.width - width) / 2,
                y: rect.minY,
                width: width,
                height: height
            )
        } else {
            let width = rect.width
            let height = width / aspectRatio
            return CGRect(
                x: rect.minX,
                y: rect.minY + (rect.height - height) / 2,
                width: width,
                height: height
            )
        }
    }

    /// Each mask image uses the exact same canvas size as `BodyFront` / `BodyBack`.
    /// Non-muscle pixels are fully transparent, so overlays stack 1:1 without extra placement math.
    private struct HeatmapMaskLayer: Identifiable {
        let id: String
        let catalogMuscle: String
        let assetName: String
    }

    @ViewBuilder
    private func muscleMaskOverlay(asset: String, imageRect: CGRect, tint: Color) -> some View {
        Rectangle()
            .fill(tint)
            .mask(
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageRect.width, height: imageRect.height)
            )
            .frame(width: imageRect.width, height: imageRect.height)
            .position(x: imageRect.midX, y: imageRect.midY)
            .allowsHitTesting(false)
    }

    // Final front overlay set.
    private static let frontMaskLayers: [HeatmapMaskLayer] = [
        HeatmapMaskLayer(id: "front_trap", catalogMuscle: "Shoulders (Front/Mid)", assetName: "MMask_front_trap"),
        HeatmapMaskLayer(id: "front_shoulders", catalogMuscle: "Shoulders (Front/Mid)", assetName: "MMask_front_shoulders"),
        HeatmapMaskLayer(id: "front_chest", catalogMuscle: "Chest", assetName: "MMask_front_chest"),
        HeatmapMaskLayer(id: "front_biceps", catalogMuscle: "Biceps", assetName: "MMask_front_biceps"),
        HeatmapMaskLayer(id: "front_forearm", catalogMuscle: "Biceps", assetName: "MMask_front_forearm"),
        HeatmapMaskLayer(id: "front_abs_rectus", catalogMuscle: "Abs", assetName: "MMask_front_abs_rectus"),
        HeatmapMaskLayer(id: "front_abs_oblique", catalogMuscle: "Abs", assetName: "MMask_front_abs_oblique"),
        HeatmapMaskLayer(id: "front_quad", catalogMuscle: "Quads", assetName: "MMask_front_quad"),
        HeatmapMaskLayer(id: "front_quad_vl", catalogMuscle: "Quads", assetName: "MMask_front_quad_vl"),
        HeatmapMaskLayer(id: "front_adductor", catalogMuscle: "Quads", assetName: "MMask_front_adductor"),
        HeatmapMaskLayer(id: "front_calf", catalogMuscle: "Quads", assetName: "MMask_front_calf")
    ]

    // Final back overlay set.
    private static let backMaskLayers: [HeatmapMaskLayer] = [
        HeatmapMaskLayer(id: "back_upper", catalogMuscle: "Upper Back (Traps)", assetName: "MMask_back_upper"),
        HeatmapMaskLayer(id: "back_lower", catalogMuscle: "Lower Back", assetName: "MMask_back_lower"),
        HeatmapMaskLayer(id: "back_shoulders", catalogMuscle: "Upper Back (Traps)", assetName: "MMask_back_shoulders"),
        HeatmapMaskLayer(id: "back_triceps", catalogMuscle: "Triceps", assetName: "MMask_back_triceps"),
        HeatmapMaskLayer(id: "back_forearm", catalogMuscle: "Triceps", assetName: "MMask_back_forearm"),
        HeatmapMaskLayer(id: "back_lats", catalogMuscle: "Lats", assetName: "MMask_back_lats"),
        HeatmapMaskLayer(id: "back_glute", catalogMuscle: "Glutes", assetName: "MMask_back_glute"),
        HeatmapMaskLayer(id: "back_ham", catalogMuscle: "Hamstrings", assetName: "MMask_back_ham"),
        HeatmapMaskLayer(id: "back_calf", catalogMuscle: "Hamstrings", assetName: "MMask_back_calf")
    ]
}

extension View {
    func glassTextField() -> some View {
        modifier(GlassTextFieldStyle())
    }

    func secondaryHelperText() -> some View {
        self
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
    }

    func tertiaryHelperText() -> some View {
        self
            .font(.caption2)
            .foregroundStyle(AppTheme.textTertiary)
    }
}
