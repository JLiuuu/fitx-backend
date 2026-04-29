# Launch Week 2 Checklist

## Focus
Ship-readiness: integration readiness, settings/data controls, observability, and final polish.

## Day 6-7: Assistant Integration Readiness
- [ ] Keep local assistant parser as fallback.
- [ ] Define structured response contract for backend AI integration.
- [ ] Ensure UI can switch local/remote without redesign.

**Acceptance**
- [ ] Assistant path works even if remote AI is offline.

## Day 7-8: Settings + Account Polish
- [ ] Finalize settings hierarchy and copy.
- [ ] Add data export/reset local data actions.
- [ ] Validate sign-out and local-state behavior.

**Acceptance**
- [ ] Users can understand and control their data states.

## Day 8-9: Observability
- [ ] Add basic analytics events for key actions.
- [ ] Add crash/error logging hook.

**Acceptance**
- [ ] Core errors and failures are diagnosable post-release.

## Day 9-10: UX Polish + Release Sweep
- [ ] Polish empty/loading/error states in all tabs.
- [ ] Final copy consistency pass (English-only).
- [ ] Final release checklist run.

**Acceptance**
- [ ] No dead-end screens in core user journey.
- [ ] Build is ready for TestFlight/App Store submission.

## Week 2 Daily Tracker
- [ ] D6
- [ ] D7
- [ ] D8
- [ ] D9
- [ ] D10

## Ship Definition (DoD)
- [ ] Onboarding completes with profile + primary goal persisted.
- [ ] Goal update from Settings immediately updates recommendations.
- [ ] Home calories/macros rings reflect logged meal/workout data correctly.
- [ ] Assistant input flow is stable (text + voice-to-text + add action).
- [ ] Permission-denied states are recoverable and non-blocking.
- [ ] Core tests pass and release checklist is clean.
