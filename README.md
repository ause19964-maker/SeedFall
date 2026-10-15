# SEEDFALL — The Living Memory of Seeds

> Know what you have. Know what the evidence says. Understand what is at risk. Know what to do next.

SEEDFALL is a local-first, single-user application for community seed banks and seed custodians. It keeps a registry of **varieties, accessions (documented sources) and physical batches**, the **evidence** behind them, **germination tests** and **storage observations**, a **distribution ledger**, **rule-based preservation alerts**, **preservation plans** with owned and dated tasks, and read-only **QR seed passports**. Every warning cites its records and the rule it applied. Nothing is predicted by AI; all rules are deterministic, documented and labelled “rule-based”.

A new installation starts **empty**. Fictional records exist only in an explicitly opened, separate **demonstration workspace**.

## What it does

A dark, glass-panel interface (forest green, emerald, sage) with one sidebar and a persistent **Add seed** button and **notification bell** in the same place on every page. Pages that belong together share one sidebar entry and switch with tabs.

| Sidebar | What is there (tabs) |
|---|---|
| **Home** | Answers *What seeds do we have?* (counts, recorded stock, holdings coverage), *What needs attention?* (open alerts by severity) and *What should I do next?* (due tasks, next steps from alerts, actions awaiting approval). Onboarding when empty. |
| **Seed Registry** | Varieties · Accessions · Custodians |
| **Batches** | Batches (each with a passport page: identity, provenance, custody, tests, observations, distributions, evidence, open alerts, QR passport, audit) · Distributions |
| **Alerts & Tasks** | Alerts (filter, acknowledge, resolve, dismiss) · Plan tasks · Actions for approval · History & checks |
| **Germination Tests** | All tests, latest result per batch (chart + table) |
| **Storage** | Storage observations |
| **Preservation Plans** | Plans · **Last Seed Guardian** · Scenario simulator (Last Seed Protocol) · Saved scenarios |
| **Reports** | Conservation status · Measures · Data quality · Review queue · Evidence documents · Audit history |
| **Settings** | General (operator, rule thresholds, demonstration) · Alerts & notifications · Import · Export & backup |

Key distinctions the application keeps:

- **Physical holdings** (distinct custodians holding active stock — resilience to a local loss) vs **documented sources** (distinct accession lineages with recorded provenance). Neither proves genetic diversity.
- **Recorded**, **derived**, **historical**, **hypothetical**, **proposed**, **unverified**, **reviewed** and **conflicting** values are labelled. “Reviewed” means a named person checked an entry; nothing is called “verified”.
- A germination result is a dated measurement, never live viability. Storage-air RH is not seed moisture. Zero recorded stock does not mean extinct. Missing values are “Not recorded” or “unknown”, never zero.
- SEEDFALL never says a variety is extinct or that a lot is “the last seed”. It says: **“No independent backup is recorded in this workspace.”**

## Prerequisites

- **Python 3.11+** (tested 3.11.15 and 3.13) — on Windows tick *Add python.exe to PATH*
- **Node.js 18+ LTS** with npm (tested Node 22)
- Internet **on first start only** to download packages. SEEDFALL then runs fully offline. (`tzdata` is installed so time zones work on Windows.)

## Start (Windows)

Double-click **`START_SEEDFALL.bat`**. It checks Python and Node, creates `.venv`, installs pinned packages when they change, initialises or safely upgrades the database (with a backup first), starts the backend and frontend in windows titled *SEEDFALL backend* / *SEEDFALL frontend*, waits until both answer, and opens the browser. If SEEDFALL is already running it only opens it. **`STOP_SEEDFALL.bat`** closes exactly those two windows.

> The `.bat` files have not been executed on native Windows in this build (see QA_REPORT.md).

## Start (manual, any OS)

```bash
python -m venv .venv
.venv/bin/pip install -r backend/requirements.txt          # Windows: .venv\Scripts\pip
cd backend && ../.venv/bin/python -m app.bootstrap          # create or upgrade the database (never inserts fictional data)
../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
# second terminal
cd frontend && npm ci && npm run dev
```

- App: <http://127.0.0.1:5173>
- API documentation: <http://127.0.0.1:8000/docs>

## Your first records

1. **Settings → General → Operator**: enter your name. It is recorded as *entered by*, reviewer, approver and audit actor. (This is not a login.)
2. **Settings → Alerts & notifications**: check the **time zone** (use the “Use this computer's zone” link) so due dates fall on the right day.
3. Press **Add seed** (top right on every page). Three short steps: the variety, where the seed came from (accession), and the physical batch with who holds it. Nothing is saved until the last step; if a step fails, what was saved is listed and “Try again” never creates duplicates.
4. On the accession page, **Add evidence** (packet label, exchange letter, custodian statement; optional PDF/PNG/JPG/TXT/CSV up to 10 MB).
5. From the batch page, record a **germination test** and a **storage observation**, and optionally a **next review date** (Edit batch → Additional details).
6. Open **Alerts & Tasks** and press **Check now**, or wait for the automatic check.

## Preservation alerts

Rule-based checks of stored records. Each alert stores its category, severity, due date, exact reason, evidence, the rule, its uncertainty, the records it refers to, a recommended next step, its status (open → acknowledged → resolved or dismissed), who decided and why, and every notification attempt.

| Rule | Raised when | It never claims |
|---|---|---|
| Review date | A recorded **next review date** is within a reminder window, today, or passed | that the seed has expired — a review date is not an expiry date |
| Germination retest | The latest **valid** test reaches the configured review age (Settings → General) | that the seed has declined |
| Germination result | The latest valid result is below the review threshold | present viability (it is one sample on one date) |
| Storage reading | The latest observation exceeds the temperature or storage-air RH limit | anything about seed moisture or damage |
| Evidence gap | An active batch has no test, no storage observation, no accession / provenance or no custodian, or its latest test record is internally inconsistent | that missing data means failure — it is reported as unknown |
| Independent backup | A variety is held by one custodian or none | rarity or extinction |
| Task due | An open plan task or preservation action has a due date in a reminder window, today, or passed | — |

- **Reminders**: default 30, 14, 7 and 1 days before, on the day, and once overdue (configurable). Each stage notifies once; a repeated check never duplicates an alert or a notification (unique per event and per stage, enforced by the database).
- **Automatic resolution**: when the records no longer meet a rule (a new test, a completed task…), the alert is resolved by “SEEDFALL” with an explanation. Alerts you **dismiss** or **resolve** are not raised again for the same event.
- **Notification centre**: the bell shows the unread count and links straight to the alert and the affected record.

### When checks run

- **While SEEDFALL is running**, the backend checks every 60 minutes (and shortly after start-up), whether or not a browser is open. Change the interval with `SEEDFALL_ALERT_INTERVAL_MINUTES`; disable with `SEEDFALL_SCHEDULER=0`.
- **Check now** on Alerts & Tasks runs the same check immediately. **History & checks** lists every run with what it found.
- **From the command line** (no server needed): `cd backend && ../.venv/bin/python -m app.alert_runner` (`--today YYYY-MM-DD` to evaluate as of another date; `--no-email` to skip e-mail).

### Scheduled alert checks on Windows (while SEEDFALL is closed)

`RUN_ALERT_CHECK.bat` runs one check and appends the result to `backend\data\alert-checks.log`. Schedule it hourly with Task Scheduler, from a Command Prompt in the SEEDFALL folder:

```bat
schtasks /Create /SC HOURLY /TN "SEEDFALL alert check" /TR "\"%CD%\RUN_ALERT_CHECK.bat\""
schtasks /Run /TN "SEEDFALL alert check"          :: test it once now
schtasks /Delete /TN "SEEDFALL alert check" /F    :: remove it
```

Running it while SEEDFALL is open is safe. To test locally without Windows: `python -m app.alert_runner --today 2026-12-01` shows reminders falling due on that date.

### Optional e-mail

In-app notifications need nothing external. E-mail is off unless SMTP settings are present in the **backend environment** (never in the database, never shown in the browser):

```
SEEDFALL_SMTP_HOST=smtp.example.org
SEEDFALL_SMTP_PORT=587                 # default 587 (465 for ssl)
SEEDFALL_SMTP_SECURITY=starttls        # starttls | ssl | none
SEEDFALL_SMTP_USER=...                 # optional
SEEDFALL_SMTP_PASSWORD=...             # optional
SEEDFALL_SMTP_FROM=seedbank@example.org
```

On Windows set them before starting (e.g. `setx SEEDFALL_SMTP_HOST smtp.example.org`, then open a new window and run START_SEEDFALL.bat). Then, in **Settings → Alerts & notifications**, add recipients, choose which severities to send, switch e-mail on, and use **Send a test e-mail**. “Sent” means the mail server accepted the message — not that anyone received it. Temporary failures are retried — up to 4 attempts in total, waiting 5, 15 and then 60 minutes between them —; every attempt and error is stored on the alert. Browser push notifications are **not** implemented.

## Last Seed Guardian and preservation plans

**Preservation Plans → Last Seed Guardian** is a six-step review of one variety or batch:

1. Select a variety (and optionally one batch).
2. Review the actual evidence: recorded quantities and when they last changed, test history (inconsistent records are shown and not used), storage observations, provenance, recorded independent backups, outstanding actions and plans, open alerts, and missing or stale evidence.
3. Potential risks — each with its evidence, rule and uncertainty, labelled rule-based.
4. Suggested actions (verify stock, inspect storage, schedule a germination test, investigate regeneration, identify a backup source, document provenance), each editable, with owner and due date.
5. Create a preservation plan from the chosen tasks. The review is saved with the plan (recomputed on the server).
6. Preview a loss: a hypothetical scenario that re-reads the records afterwards to show nothing changed. The full **Scenario simulator** (Last Seed Protocol) adds interventions and saved scenarios.

Plans and tasks never change stock. Completing a task needs a written outcome and a named operator; a plan can be completed only when no task is open. Open tasks with due dates are reminded by the alert engine.

## QR seed passports

On a batch page, **Create seed passport** gives the batch a random, unguessable link and a QR code; **Print label** shows a small black-and-white label. The passport page is read-only and shows identifier, variety, accession and origin, recorded quantity, latest valid germination test, storage history and open alerts. It never shows the custodian, storage location, people's names, notes or attachments. **Replace link** makes every printed code for the old link stop working.

A QR code only opens where the SEEDFALL server can be reached. By default that is **this computer only** (`127.0.0.1`). SEEDFALL has no login, so making it reachable from phones on a network would expose the whole application, not just passports — this build does not do that, and it is not recommended. `SEEDFALL_PUBLIC_BASE_URL` changes the address encoded in new QR codes if you host access deliberately.

## Importing an existing catalogue

**Settings → Import**: choose what the file contains, upload, map columns, check every row, then import the valid rows in one transaction. Existing records are never overwritten; formulas are never evaluated; rejected rows can be downloaded with reasons. Full column reference: [docs/IMPORT_TEMPLATES.md](docs/IMPORT_TEMPLATES.md). Templates: [docs/import-templates/](docs/import-templates/).

## Data, backup and restore

- Operational database: `backend/data/seedfall.db` (override with `SEEDFALL_DATABASE_URL`).
- Demonstration database: `backend/data/seedfall-demo.db` (separate file; created only when you open the demonstration).
- Evidence attachments: `backend/data/seedfall-attachments/` (stored under random names).
- Backups: `backend/data/backups/`. **Settings → Export & backup → Create backup now** writes a consistent copy; every schema upgrade writes one automatically first (`*-pre-v2-*.db`, `*-pre-v3-*.db`).
- **Restore:** stop SEEDFALL (`STOP_SEEDFALL.bat`), copy the chosen backup over `backend/data/seedfall.db` (delete any `seedfall.db-wal` / `seedfall.db-shm` beside it), start again.

### Upgrading

- **From v2 (schema 2)**: on first start SEEDFALL backs the database up, then only **adds** the alert, notification, check, plan and task tables and two batch columns (`review_date`, `passport_token`). Nothing is removed or rewritten.
- **From v1**: as in v2 — backup, then v1 demo rows that none of your records depend on are removed (rows you depend on are kept and labelled “Fictional”) — followed by the v3 additions.

## Tests

```bash
cd backend && ../.venv/bin/python -m pytest -q                       # isolated temp databases
cd frontend && npm run typecheck && npm run lint && npm test && npm run build
./scripts/run_e2e.sh      # fresh-install browser journeys incl. a real backend restart (Linux/macOS shell)
```

## Configuration (all optional)

| Variable | Purpose |
|---|---|
| `SEEDFALL_DATABASE_URL`, `SEEDFALL_DEMO_DATABASE_URL` | Database locations |
| `SEEDFALL_TIMEZONE` | Default time zone until one is chosen in Settings (otherwise `TZ`, then UTC) |
| `SEEDFALL_SCHEDULER`, `SEEDFALL_ALERT_INTERVAL_MINUTES`, `SEEDFALL_ALERT_FIRST_DELAY_SECONDS` | In-server alert checks |
| `SEEDFALL_SMTP_*` | Optional e-mail (see above) |
| `SEEDFALL_PUBLIC_BASE_URL` | Address encoded in new QR codes and e-mail links |
| `SEEDFALL_CORS_ORIGINS`, `SEEDFALL_API_URL`, `VITE_API_BASE_URL` | Networking for development |
| `SEEDFALL_TODAY` | Pin “today” (tests only) |

## Troubleshooting

| Symptom | Fix |
|---|---|
| Red “server is not reachable” bar | The backend window closed or failed; read it and rerun START_SEEDFALL.bat. |
| Port 8000 or 5173 in use | Close the other program or run STOP_SEEDFALL.bat. |
| “Set your name … first” | Settings → General → Operator. |
| Alerts fall on the wrong day | Settings → Alerts & notifications → Time zone. |
| No automatic checks | History & checks shows the scheduler state; it runs only while the backend runs — schedule RUN_ALERT_CHECK.bat for the rest. |
| E-mail switch refused | SMTP variables are missing from the backend environment, or no recipient is saved. |
| QR code does not open on a phone | Expected: the link points to this computer (see QR seed passports). |
| Import rejects dates | Use `YYYY-MM-DD`. |
| Startup says the schema version is newer | The database came from a newer SEEDFALL; nothing was changed. Use that version or a backup. |

## Limitations

Single-user and local only: no authentication, roles or multi-user conflict handling beyond SQLite transactions; the operator name is not a security control. Thresholds are configurable heuristics, not biological standards, and storage limits are global rather than per storage method. No viability, yield or loss prediction. Records cannot establish genetic diversity or that seed does not exist elsewhere. Restore is a manual file copy. Browser push notifications are not implemented; e-mail delivery was tested only against a simulated SMTP server. Windows `.bat` files were not executed on Windows in this build. Not independently security-reviewed; not production-certified.
