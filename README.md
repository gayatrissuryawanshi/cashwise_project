# CashWise - Integrated Project

This folder combines the two pieces you uploaded, now wired together:

- **`backend/`** - the CashFlow Engine FastAPI backend (auth + ML + decision
  engine), unchanged from what you uploaded.
- **`frontend/`** - the CashWise Flutter app, rewritten to actually call the
  backend above instead of using mock data and a placeholder API contract.

See `frontend/README.md` for exactly what changed and how to run both
pieces together.

## Quick start

**1. Backend**
```
cd backend
python -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

**2. Frontend** - first open `frontend/lib/services/api_service.dart` and set
`baseUrl` to point at the machine running the backend (see the comment at
the top of that file), then:
```
cd frontend
flutter pub get
flutter run
```

**3. Try it** - sign up, then upload `backend/BUSINESS_DATA_TEMPLATE.xlsx`
from the Dashboard's "Upload Excel" button. You'll get a real safe-to-deploy
recommendation, receivable risk breakdown, and 30-day cash forecast, all
driven by the actual FastAPI backend.

## What "integration" means here

Before: the Flutter app was 100% hardcoded UI (`MockData`) and its
`ApiService` pointed at endpoints (`/dashboard/{id}`, `/udhaar/{id}`,
`/upload-excel`, `/funding-alternative`) that the backend never
implemented - the two projects had never actually been connected.

Now: every screen reads from a shared `AppState` that calls the backend's
real endpoints (`/signup`, `/login`, `/analyze`, `/analyses`,
`/evaluate-spend`, `/simulate`) and renders the actual JSON those endpoints
return. A login screen was added since every backend endpoint requires a
JWT. The one gap that couldn't be closed by rewiring alone -
`/funding-alternative` doesn't exist on the backend - is called out
explicitly in the Safe Alternative screen, which now derives its suggestion
from real data instead of calling a URL that would 404.

I wasn't able to run `flutter pub get` / `flutter analyze` in this
environment (no network access here), so this hasn't been compiled - it's
hand-written against the exact request/response shapes read from
`backend/main.py`, `backend/integration.py`, and `backend/engine/*.py`.
Worth a `flutter pub get && flutter analyze` pass on your machine before
you demo it.
