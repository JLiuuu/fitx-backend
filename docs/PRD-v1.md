# AI Fitness Coach - PRD v1

## 1) Product Goal
Build a practical recovery and training assistant that helps users answer three daily questions:
- How recovered am I today?
- What should I train (or avoid) today?
- Am I eating enough (calories + macros) for my goal?

This is a product-grade estimate system, not a medical diagnosis.

## 2) Users and Plans

### Target users
- Users training for muscle gain, fat loss, or maintenance
- Users with or without Apple Watch
- Users wanting simple logging + clear guidance

### Plan strategy
- **Free**: manual-first logging, basic AI coach guidance
- **Pro**: camera meal logging, voice workout logging, advanced actionable AI coach

## 3) Authentication and First-Run Flow

### First app launch
1. Launch screen
2. Login / Register
3. Registration options:
   - Phone/email
   - Apple / Google / Facebook
4. First-time profile setup:
   - Age (required)
   - Sex (required)
   - Height (required) with unit toggle: `cm` / `ft+in`
   - Weight (required) with unit toggle: `kg` / `lbs`
5. System-calculated:
   - BMI (auto, not user-entered)
   - BMR (shown with short explanation)
6. Enter main app

### Returning users
- Auto-enter app (no login prompt)
- Show login only after explicit sign-out

## 4) Navigation (Bottom Tabs)
- `Recovery`
- `Nutrition`
- `Training`
- `Settings`

## 5) Page Requirements

## 5.1 Recovery (Home)
Module order:
1. Recovery score (0-100 + status)
2. Daily energy summary: `Burned / Eaten / Net`
3. Muscle heatmap (front/back switch)
4. AI Coach card

### AI Coach card
- **Free**: direction-level advice (what to train/avoid)
- **Pro**: actionable plan (specific exercise suggestions + intensity hints)
- Pro CTA examples:
  - `Start Today's Workout`
  - `Ask AI Coach`
  - `Regenerate`

## 5.2 Nutrition
Core:
- Add food entries
- Show total calories + macro totals (protein/carbs/fat)
- Food list with delete/edit

### Free
- Manual food input
- Gemini-assisted estimate for calories/macros
- User confirmation/edit before save

### Pro
- Camera-based food recognition
- Confirmation popup to correct recognition/portion
- Save to list and update totals

## 5.3 Training (Training & Expenditure)
Top summary:
- Daily total expenditure (TDEE)
- Breakdown:
  - BMR
  - Daily activity burn
  - Workout burn

Middle:
- Workout log list (editable/deletable)

Add workout:
- **Free / no watch**: manual modal
  - Exercise name
  - Sets
  - Reps
  - Optional RPE
  - Buttons: Cancel / Confirm
- **Pro**: voice input to structured workout entry

## 5.4 Settings
Sections:
1. Account & Subscription
2. Apple Health integration (status + last sync)
3. Units (height/weight)
4. Goal settings (gain/fat-loss/maintain)
5. Notifications
6. Privacy & Support (export/delete account/help)

## 6) Recovery and Fatigue Model (v1)

## 6.1 Muscle groups used by product

### Front
- Chest
- Shoulders (Front/Mid)
- Biceps
- Abs Rectus
- Abs Oblique / Serratus
- Quads
- Vastus Lateralis (Outer Quad)
- Adductors
- Calves
- Forearms
- Front Traps

### Back
- Upper Back / Traps
- Rear Delts
- Triceps
- Lats
- Lower Back
- Glutes
- Hamstrings
- Calves
- Forearms

## 6.2 Training contribution logic
- Each exercise maps to multiple muscles via weighted contribution
- Total training stimulus is split by contribution weights
- Per-muscle fatigue score is updated in `[0, 100]`

## 6.3 Health-based global recovery signal
HealthKit inputs:
- Workout
- Heart Rate
- HRV (SDNN)
- Resting Heart Rate
- Active Energy Burned
- Apple Exercise Time
- Step Count
- Sleep Analysis

Output:
- Global Recovery/Readiness score (0-100)
- This score modulates both:
  - Daily recovery speed
  - Training fatigue gain sensitivity

## 7) AI Coach Free vs Pro

### Free
- 1 daily basic coaching refresh
- Directional recommendation (train/avoid focus)
- Basic nutrition gap reminders
- No deep interactive coaching

### Pro
- Unlimited refresh
- Actionable recommendations (exercise-level)
- Voice Q&A and follow-up
- Trend-aware coaching (7-14 day context)
- One-tap workout plan start

## 8) Edge Cases
- HealthKit denied: app remains usable with manual logging fallback
- No Apple Watch: manual training + nutrition still works
- AI uncertainty: require confirmation popup for recognized meals
- Network/API failure: keep local logs and allow retry

## 9) Success Metrics
- D1 / D7 retention
- HealthKit authorization rate
- Daily logging completion (training + nutrition)
- AI coach engagement rate
- Free-to-Pro conversion

## 10) Scope

### v1 must-have
- Auth + first-run setup
- 4-tab architecture
- Recovery page with heatmap + AI coach
- Nutrition logging (free manual + pro camera)
- Training logging (free manual + pro voice)
- HealthKit-driven readiness in daily experience

### v1.5 / v2
- Finer muscle modeling
- Personalized parameter adaptation
- Weekly/monthly trend reports
- Auto periodized plan suggestions

---

## Development Priority Checklist

1. **Auth + Onboarding**
   - Add login/register states
   - Save onboarding profile + unit preferences
   - Compute BMI/BMR automatically

2. **Navigation and Page Shells**
   - Ensure 4-tab navigation structure is final
   - Confirm naming (`Recovery`, `Nutrition`, `Training`, `Settings`)

3. **Recovery Home Integration**
   - Place burn/eaten/net row under readiness
   - Keep front/back heatmap switch stable
   - Add AI coach card state machine (free/pro/health-unavailable)

4. **Nutrition Flows**
   - Free manual + AI estimate confirm flow
   - Pro camera recognition + correction popup
   - Entry list with edit/delete

5. **Training & Expenditure Flows**
   - Expenditure breakdown UI
   - Free manual workout modal
   - Pro voice workout input pipeline
   - Workout log list with edit/delete

6. **AI Coach Productization**
   - Free/pro gating
   - Action buttons (`Start`, `Ask`, `Regenerate`)
   - Upgrade prompts where appropriate

7. **Hardening**
   - Empty states, permission denied states
   - Persistence checks and migration safety
   - QA pass for unit toggles and daily totals
