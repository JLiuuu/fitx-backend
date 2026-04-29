# Launch Week 1 Checklist

## Focus
Core stability, data correctness, parser reliability, and permission robustness.

## Day 1-2: Data Reliability
- [ ] Add safer delete flows for meals/workouts (confirm + optional undo).
- [ ] Normalize unit handling (`kg/lbs`, `kcal`) and stored value consistency.
- [ ] Guard against incomplete entries before save.

**Acceptance**
- [ ] No accidental destructive delete in core flows.
- [ ] Stored nutrition/training values remain consistent after edits.

## Day 2-3: Parser Hardening (Workout + Meal)
- [ ] Expand parser coverage for common phrasing variants.
- [ ] Improve missing-field fallback prompts.
- [ ] Improve noisy speech text tolerance.

**Acceptance**
- [ ] Most common inputs parse without manual cleanup.
- [ ] Invalid parses fail gracefully with clear feedback.

## Day 3-4: Target Model Calibration
- [ ] Add activity level setting (`low/medium/high`).
- [ ] Apply activity level to calorie target recommendation.
- [ ] Separate recommendation behavior for training vs rest days.

**Acceptance**
- [ ] Recommendation changes when activity level changes.
- [ ] Suggested calories/macros feel plausible across profiles.

## Day 4-5: Health + Permission Robustness
- [ ] Improve denied/unavailable permission messaging.
- [ ] Add retry flow and non-blocking fallback states.
- [ ] Ensure app remains usable without HealthKit/Speech access.

**Acceptance**
- [ ] Permission denial never blocks manual logging.
- [ ] Recovery/Nutrition pages stay functional in degraded mode.

## Day 5: Critical Tests
- [ ] Unit tests: nutrition target logic.
- [ ] Unit tests: fatigue/recovery update logic.
- [ ] Unit tests: parser extraction logic.
- [ ] UI smoke tests: onboarding -> tabs -> add meal/workout.

**Acceptance**
- [ ] Core tests pass locally on clean build.

## Week 1 Daily Tracker
- [ ] D1
- [ ] D2
- [ ] D3
- [ ] D4
- [ ] D5
