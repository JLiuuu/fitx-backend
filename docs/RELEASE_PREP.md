# AI Fitness Coach Release Prep

## 1) Backend Configuration
- Default backend URL is `http://localhost:8000`.
- Override with env var `FITNESS_BACKEND_URL`.
- Required endpoints:
  - `POST /api/meal/scan`
  - `POST /api/coach/today`

## 2) StoreKit Setup
- Product IDs expected by app:
  - `com.fitnesscoach.pro.monthly`
  - `com.fitnesscoach.pro.yearly`
- In `Profile`, use **Sync Subscription from StoreKit** to pull active entitlements.

## 3) Functional Validation
- Run `Home -> Run End-to-End Beta Loop`.
- Validate Recovery, Nutrition, Coach, and Profile screens update coherently.
- Relaunch app and verify persisted state restores.

## 4) Build Command
```bash
xcodebuild -project "fitnesscoach.xcodeproj" -scheme "fitnesscoach" -destination "platform=macOS" -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build
```

## 5) Test Command
```bash
xcodebuild test -project "fitnesscoach.xcodeproj" -scheme "fitnesscoach" -destination "platform=macOS" -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO
```

## 6) TestFlight Handoff Checklist
- Replace placeholder bundle ID.
- Configure signing/team and distribution certs.
- Set App Privacy + Health data usage strings.
- Configure production backend URL.
- Verify StoreKit products are approved and available.
