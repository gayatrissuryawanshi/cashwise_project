# CashFlow Engine — Combined Backend

One backend, merged from the three separate pieces:

| Piece | What it contributes | Where it lives now |
|---|---|---|
| `backend.zip` | Login/signup (JWT auth) | `auth.py`, `main.py` (`/signup`, `/login`) |
| `decision_engine...zip` | The "brain": safe-to-deploy, allocation, why-explanations, risk, fragility, counterfactuals | `engine/` package |
| `forecast_new.zip` | ML: 30-day sales forecast + customer "udhaar" (credit) payment-behavior prediction | `ml/` package |

`integration.py` is the file that actually connects them: it feeds the udhaar model's
predictions into the decision engine's receivables, so a customer predicted to pay late
is automatically trusted for less money — see **How the integration works** below.

Everything is saved in **one** database (SQLite by default, Postgres optional) instead
of three separate/missing ones.

---

## 1. Setup

Requires Python 3.10+.

```bash
cd cashflow-engine
python -m venv venv

# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate

pip install -r requirements.txt
```

By default the app uses a local SQLite file (`cashflow.db`) — nothing else to install
or configure. Tables are created automatically the first time you run the server.

**Optional — use PostgreSQL instead:** set the `DATABASE_URL` environment variable
before starting the server (do this every time you open a new terminal, or add it to
your shell profile):

```bash
# Windows PowerShell
$env:DATABASE_URL = "postgresql://postgres:YOUR_PASSWORD@localhost:5432/finance_engine"

# macOS/Linux
export DATABASE_URL="postgresql://postgres:YOUR_PASSWORD@localhost:5432/finance_engine"
```

If you do this, also run `pip install psycopg2-binary` and make sure the
`finance_engine` database already exists in Postgres.

## 2. Run it

```bash
uvicorn main:app --reload --port 8000
```

Open `http://localhost:8000/docs` — that's an interactive Swagger UI where you can try
every endpoint by hand (no separate frontend needed to test).

## 3. Try the full flow

1. **Sign up** — `POST /signup` with `{"name": "...", "email": "...", "password": "..."}`
2. **Log in** — `POST /login` with the same email/password. Copy the `access_token`
   from the response.
3. In Swagger UI, click **Authorize** (top right) and paste the token (just the token,
   Swagger adds the `Bearer ` prefix for you).
4. **Upload the sample Excel** — `POST /analyze`, choose `BUSINESS_DATA_TEMPLATE.xlsx`
   (included in this folder). You'll get back:
   - the recommended allocation of safe-to-spend cash across actions (inventory,
     marketing, equipment repair), with plain-English reasons
   - the receivables, risk-adjusted using the ML payment predictions
   - the 30-day sales forecast
   - the udhaar (customer credit) predictions
   - a combined cash forecast
   - `analysis_id` — save this to re-query later
5. **Re-check a spend without re-uploading** —
   `POST /analyses/{analysis_id}/evaluate-spend` with `{"proposed_amount": 50000}`
6. **See past uploads** — `GET /analyses`

## 4. Your own Excel file

Copy `BUSINESS_DATA_TEMPLATE.xlsx` and edit the numbers, or build your own workbook
with these sheets (sheet names matter, case-sensitive):

- **`BusinessData`** *(required)* — one sheet, following the block layout already in
  the template: business facts, then `Current_Cash` / `Minimum_Reserve` / `Risk_Buffer`,
  then obligations (any row with a number becomes one — Salary, Rent, etc. are just
  examples), then a receivables table, then an actions table. Full column-by-column
  documentation is in the comment at the top of `engine/excel_loader.py`.
- **`Sales`** *(optional)* — two columns, `Date` and `Sales`. Needs at least 60 days
  of history for the forecast model to train. Skipped (not an error) if missing or
  too short.
- **`Udhar`** *(optional)* — columns `Customer_ID`, `Credit_Date`, `Amount`,
  `Due_Date`, `Payment_Date` (blank `Payment_Date` = still unpaid). Needs a handful of
  repeat customers with several payments each. Skipped (not an error) if missing or
  too short.

**Important:** for the ML risk-adjustment to apply to a receivable, that receivable's
name in the `BusinessData` sheet's receivables table must **exactly match** (case
insensitive) a `Customer_ID` in the `Udhar` sheet — that's how the two are linked. In
the template, "Ramesh Kirana" appears both places, for example.

## 5. How the integration works

When you upload a workbook to `POST /analyze`, `integration.run_full_analysis()`:

1. Reads the `BusinessData` sheet into a `BusinessState` (cash, obligations,
   receivables, actions) using the decision engine's own Excel loader — unchanged.
2. If a `Sales` sheet is present with enough history, trains and runs the sales
   forecast model (30 days ahead) — informational, shown in the response, not fed
   into the optimizer's math (see note below).
3. If an `Udhar` sheet is present with enough history, trains and runs the udhaar
   payment-behavior model, predicting each customer as `EARLY` / `ON TIME` / `LATE`
   with a confidence percentage.
4. **The key step:** for every receivable whose name matches a customer the ML model
   scored, its `reliability_score` is overwritten based on that prediction (a
   confident "LATE" prediction pushes reliability down toward 0.1; a confident
   "EARLY"/"ON TIME" prediction pushes it up toward 1.0 — see
   `integration.udhar_prediction_to_reliability` for the exact, deliberately simple
   formula). This is the same `reliability_score` field the decision engine already
   uses to discount receivables — nothing in `engine/` had to change for this to work.
5. Runs the decision engine's `recommend()` on the now ML-adjusted state.
6. Builds the combined sales + expected-collections cash forecast too, for context.

**Scope note:** the sales forecast and combined cash forecast are returned as extra
business intelligence for the dashboard, but only the **udhaar risk model** feeds back
into the actual spend recommendation. Wiring predicted future sales into the safe-to-
deploy calculation itself would be a reasonable next step, but changes the meaning of
"safe to deploy today" (today's cash vs. cash you expect to earn) and was left out to
keep that number trustworthy and explainable — flag it if you want that added next.

If a sheet is missing or doesn't have enough history, that step is skipped (not a hard
failure) and the reason shows up in the response's `ml_notes` list — a brand-new
business with no `Udhar` sheet yet still gets a full recommendation, just without the
ML risk-adjustment layered on top.

## 6. Endpoints

| Endpoint | Purpose |
|---|---|
| `POST /signup`, `POST /login` | Auth |
| `POST /analyze` | Upload an Excel workbook, get the full ML-adjusted recommendation |
| `GET /analyses` | List your past uploads (summary) |
| `GET /analyses/{id}` | Full detail of one past upload |
| `GET /analyses/latest` | Full detail of your most recent upload |
| `POST /analyses/{id}/evaluate-spend` | "Can I safely spend ₹X?" against a past upload |
| `POST /analyses/{id}/simulate` | Day-by-day cash timeline if you spend ₹X, against a past upload |

## 7. Project layout

```
main.py                  FastAPI app: auth + analyze + history endpoints
integration.py           Connects the ML models to the decision engine
database.py              DB connection (SQLite by default, Postgres via env var)
db_models.py             SQLAlchemy tables: users, analyses
auth.py                  Password hashing + JWT (from the original backend)
schemas.py               Request bodies (signup/login/spend-check)
sample_data_generator.py Regenerates BUSINESS_DATA_TEMPLATE.xlsx
BUSINESS_DATA_TEMPLATE.xlsx   Sample workbook, ready to upload as-is
requirements.txt

engine/                  The decision engine (from decision_engine.zip), unchanged
                          except import paths and one new `sheet_name` option on the
                          Excel loader so it can read from a workbook that also has
                          Sales/Udhar sheets alongside it.

ml/                       The ML models (from forecast_new.zip), unchanged except
                          import paths.
```

## 8. Known limitations / next steps

- The sales forecast model wants **60+ days** of history and the udhaar model wants a
  handful of **repeat customers** with several payments each — a brand-new business
  won't have this yet, and the app is designed to degrade gracefully in that case
  (see §5), but the ML features won't have much to work with until that data exists.
- `evaluate-spend` / `simulate` re-run against the **saved** state from the last
  upload — if the business's numbers have changed, upload a fresh Excel first.
- Passwords are hashed with bcrypt and tokens are signed JWTs, but the JWT secret key
  in `auth.py` is a hardcoded placeholder — change `SECRET_KEY` before using this
  anywhere beyond your own testing.
