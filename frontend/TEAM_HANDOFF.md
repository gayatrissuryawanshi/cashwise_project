# CashWise Flutter — Team Handoff

## Frontend scope
- Dashboard
- Excel upload / analysis flow
- Receivable Risk (UI name; backend endpoint remains `/udhaar/{business_id}`)
- Cash-flow Forecast
- AI Recommendation
- What-if Simulator
- Don't Spend → Funding Alternative flow
- More / Settings section

## API contract expected
GET /dashboard/{business_id}
GET /udhaar/{business_id}
GET /forecast/{business_id}
GET /recommendation/{business_id}
POST /simulate
POST /funding-alternative
POST /upload-excel  # confirm final backend endpoint

## Run
flutter pub get
flutter run -d chrome

For a physical Android phone, replace the API base URL with the laptop's LAN IP, e.g. http://192.168.1.5:8000. Do not use 127.0.0.1 on the phone.
