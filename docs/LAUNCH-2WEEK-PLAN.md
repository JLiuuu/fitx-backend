# 2-Week Launch Plan (MVP)

## Goal

Ship a stable v1 that supports:
- onboarding + goal-based targets
- meal/workout logging (manual + assistant flow)
- recovery + nutrition dashboard reliability
- clear permission/error handling

---

## Week 1: Core Stability and Data Correctness

### Day 1-2: Data Reliability
- [ ] Add safer delete flows for meals/workouts (confirm + optional undo).
- [ ] Normalize unit handling (`kg/lbs`, `kcal`) and stored value consistency.
- [ ] Guard against incomplete entries before save.

**Acceptance**
- [ ] No accidental destructive delete in core flows.
- [ ] Stored nutrition/training values remain consistent after edits.

### Day 2-3: Parser Hardening (Workout + Meal)
- [ ] Expand parser coverage for common phrasing variants.
- [ ] Improve missing-field fallback prompts.
- [ ] Improve noisy speech text tolerance.

**Acceptance**
- [ ] Most common inputs parse without manual cleanup.
- [ ] Invalid parses fail gracefully with clear feedback.

### Day 3-4: Target Model Calibration
- [ ] Add activity level setting (`low/medium/high`).
- [ ] Apply activity level to calorie target recommendation.
- [ ] Separate recommendation behavior for training vs rest days.

**Acceptance**
- [ ] Recommendation changes when activity level changes.
- [ ] Suggested calories/macros feel plausible across profiles.

### Day 4-5: Health + Permission Robustness
- [ ] Improve denied/unavailable permission messaging.
- [ ] Add retry flow and non-blocking fallback states.
- [ ] Ensure app remains usable without HealthKit/Speech access.

**Acceptance**
- [ ] Permission denial never blocks manual logging.
- [ ] Recovery/Nutrition pages stay functional in degraded mode.

### Day 5: Critical Tests
- [ ] Unit tests: nutrition target logic.
- [ ] Unit tests: fatigue/recovery update logic.
- [ ] Unit tests: parser extraction logic.
- [ ] UI smoke tests: onboarding -> tabs -> add meal/workout.

**Acceptance**
- [ ] Core tests pass locally on clean build.

---

## Week 2: Ship-Readiness Layer

### Day 6-7: Assistant Integration Readiness
- [ ] Keep local assistant parser as fallback.
- [ ] Define structured response contract for backend AI integration.
- [ ] Ensure UI can switch local/remote without redesign.

**Acceptance**
- [ ] Assistant path works even if remote AI is offline.

### Day 7-8: Settings + Account Polish
- [ ] Finalize settings hierarchy and copy.
- [ ] Add data export/reset local data actions.
- [ ] Validate sign-out and local-state behavior.

**Acceptance**
- [ ] Users can understand and control their data states.

### Day 8-9: Observability
- [ ] Add basic analytics events for key actions.
- [ ] Add crash/error logging hook.

**Acceptance**
- [ ] Core errors and failures are diagnosable post-release.

### Day 9-10: UX Polish + Release Sweep
- [ ] Polish empty/loading/error states in all tabs.
- [ ] Final copy consistency pass (English-only).
- [ ] Final release checklist run.

**Acceptance**
- [ ] No dead-end screens in core user journey.
- [ ] Build is ready for TestFlight/App Store submission.

---

## Highest Risk Items (Do Early)

- Parser quality under noisy voice input
- Permission edge cases (Speech + HealthKit)
- Goal target trustworthiness (recommendation quality)
- Regression risk from rapid UI iterations

---

## Daily Execution Tracker

### Week 1
- [ ] D1
- [ ] D2
- [ ] D3
- [ ] D4
- [ ] D5

### Week 2
- [ ] D6
- [ ] D7
- [ ] D8
- [ ] D9
- [ ] D10

---

## v1 Ship Definition

- [ ] Onboarding completes with profile + primary goal persisted.
- [ ] Goal update from Settings immediately updates recommendations.
- [ ] Home calories/macros rings reflect logged meal/workout data correctly.
- [ ] Assistant input flow is stable (text + voice-to-text + add action).
- [ ] Permission-denied states are recoverable and non-blocking.
- [ ] Core tests pass and release checklist is clean.
