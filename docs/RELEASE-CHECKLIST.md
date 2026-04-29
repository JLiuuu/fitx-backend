# Release Checklist (MVP)

## Core Journey
- [ ] Sign in and onboarding complete successfully.
- [ ] User profile, goal, and activity level persist after app restart.
- [ ] Main tabs open correctly: Recovery, Nutrition, Training & Expenditure, Settings.

## Logging and Targets
- [ ] Manual workout entry validates input and saves correctly.
- [ ] Manual meal entry validates input and saves correctly.
- [ ] Delete and undo flows work for workouts and meals.
- [ ] Calories/macros progress updates after meal/workout actions.
- [ ] Planned training days and logged workouts correctly affect target calculations.

## Assistant and Voice
- [ ] Workout assistant supports text input and add/apply actions.
- [ ] Meal assistant supports text input and add/apply actions.
- [ ] Voice permission flow is recoverable and non-blocking.
- [ ] Assistant remote mode falls back to local parser on failures.

## Health and Settings
- [ ] Health authorization can be requested from Settings.
- [ ] Health denied/unavailable states do not block core app usage.
- [ ] Settings can export local data JSON successfully.
- [ ] Settings reset local tracking data works with confirmation.

## Stability and Diagnostics
- [x] Unit tests pass (`fitnesscoachTests`).
- [x] No new linter diagnostics in changed files.
- [ ] Key analytics/error events appear in logs during core actions.

## Final Copy and UX
- [ ] Empty/loading/error states are understandable and English-only.
- [ ] No dead-end screens in normal user flow.

## Verification Notes
- Automated checks completed in this session:
  - `xcodebuild test -scheme fitnesscoach -destination 'platform=macOS' -only-testing:fitnesscoachTests` -> pass
  - IDE lints for `fitnesscoach/` -> no new errors
- Remaining unchecked items require in-app manual flow testing (UI interaction, permissions, and runtime behavior).
