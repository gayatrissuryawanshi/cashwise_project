# CashWise Flutter MVP

This app is now wired to the real **CashFlow Engine** backend (see
`../cashflow-engine/merged/`) instead of mock data. If you're picking this
up fresh, read this file before `TEAM_HANDOFF.md` - some of that file
describes the *old*, disconnected contract and is kept only for history.

## Current frontend flow
Login / Signup
→ Dashboard (empty state if nothing analyzed yet)
→ Upload Excel → Analyzing (real `/analyze` call) → Analysis Complete
→ Dashboard with real analyzed values
→ Receivable Risk (real `receivables_risk` breakdown + ML predictions)
→ Forecast (real day-by-day `/simulate` timeline)
→ AI Recommendation (real `recommended_allocation` + "why" explanations)
→ What-if Simulator (real `/evaluate-spend` + `/simulate`)
→ Safe Alternative (locally derived - see note below)

## Real API contract (matches `main.py`)
- `POST /signup`, `POST /login` - JWT auth, required for everything else
- `POST /analyze` - multipart Excel upload, runs the full ML + decision-engine pipeline
- `GET /analyses`, `GET /analyses/{id}`, `GET /analyses/latest` - history
- `POST /analyses/{id}/evaluate-spend` - "can I safely spend ₹X?"
- `POST /analyses/{id}/simulate` - day-by-day cash timeline if you spend ₹X

The old placeholder contract (`/dashboard/{id}`, `/udhaar/{id}`,
`/forecast/{id}`, `/recommendation/{id}`, `/upload-excel`,
`/funding-alternative`) was never implemented on the backend and has been
removed from `lib/services/api_service.dart`.

**No `/funding-alternative` endpoint exists.** `FundingScreen` now derives a
simple, transparent suggestion (reduce spend to the safe amount / chase a
specific receivable) directly from `/evaluate-spend`'s shortfall and the
recommendation's `receivables_risk` data. It's clearly labeled in the UI as
a heuristic, not a real credit product - add a backend endpoint if you want
something smarter than that.

## Where things live
- `lib/services/api_service.dart` - thin Dio wrapper around the real endpoints
- `lib/state/app_state.dart` - the app's single source of truth: auth token,
  current analysis, and derived getters the screens read from (safe-to-deploy,
  risk level, receivables breakdown, etc.). Screens no longer import `MockData`
  (that file has been deleted).
- `lib/screens/auth_screen.dart` - new; every backend endpoint requires a JWT,
  and the old prototype had no login screen at all.

## Important
1. Change `ApiService`'s default `baseUrl` (in `api_service.dart`) from
   `192.168.1.5` to wherever `uvicorn main:app` is actually running:
   - Android emulator + backend on the same machine: `http://10.0.2.2:8000`
   - Physical phone / iOS simulator: your computer's LAN IP, e.g. `http://192.168.x.x:8000`
   - Never use `127.0.0.1` on a physical device.
2. The backend already returns snake_case JSON keys - nothing to change there.
3. The JWT is kept in memory only (no `shared_preferences` dependency was
   added) - closing the app requires logging in again. Add persistence if
   that matters for your demo.
4. Upload accepts `.xlsx` / `.xlsm`, matching what `main.py` accepts.

## Run
```
cd cashflow-engine/merged
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```
```
cd cashwise_flutter
flutter pub get
flutter run
```
Sign up, then upload `cashflow-engine/merged/BUSINESS_DATA_TEMPLATE.xlsx`
from the app to see the full pipeline end to end.
