# AI Fitness Coach Beta Checklist

## Goal
Verify the full user loop works in one session:
Health sync -> workout log -> meal scan -> AI coach update.

## Manual Test Steps
1. Launch app and open `Profile`.
2. Tap `Authorize Health Data` and verify status/summary updates.
3. Return to `Home`, tap `Run End-to-End Beta Loop`.
4. Open `Recovery` and confirm readiness + workout summary changed.
5. Open `Nutrition` and confirm a new scanned meal appears with confidence and confirmation prompts.
6. Open `Coach` and verify refreshed structured advice reflects latest recovery/nutrition status.
7. Quit and relaunch app, verify state is restored (meal list, recovery values, plan, coach cards).

## Subscription Validation
- On `Profile`, switch to `Free` and verify only one meal scan is allowed per day.
- Switch to `Pro` and verify scan quota changes to unlimited.

## Expected Outcome
App should complete the full coaching cycle without crashes and persist user state across restarts.
