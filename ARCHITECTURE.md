# SEEDFALL Architecture (v3)

```
Browser ─► Vite :5173 ──/api proxy──► FastAPI :8000 ─► routers ─► services ─► SQLAlchemy ─► SQLite
                                           │                │
                                           │                ├─► intelligence.py  (conservation rules + Last Seed Protocol, pure)
                                           │                ├─► quality.py       (data-quality checks, pure)
                                           │                ├─► alerts.py        (preservation alert rules, pure)
                                           │                ├─► alert_service.py (persist alerts, reminders, deliveries, e-mail)
                                           │                ├─► guardian.py      (Last Seed Guardian review, plans)
                                           │                └─► importer.py      (parse → map → validate → commit)
                                           ├─► scheduler.py: background thread → alert check every N minutes (operational workspace)
                                           └─► database.py: two isolated workspaces
                                                  operational  data/seedfall.db       (always active after a restart)
                                                  demo         data/seedfall-demo.db  (created only on explicit request)
```

Single-user, local-first. No external services, no AI model. Optional SMTP credentials live only in the backend environment.

`python -m app.alert_runner` (wrapped by `RUN_ALERT_CHECK.bat`) runs the same alert check from the command line, so Windows Task Scheduler can run it while the server is stopped.

## Layers

| Concern | Location |
|---|---|
| Design tokens | `frontend/tailwind.config.js` (colours, radii, fonts) mirrored as CSS variables in `src/index.css` (glass surfaces with opaque fallbacks for no `backdrop-filter` and `prefers-reduced-transparency`, hatch pattern for hypothetical values, reduced-motion rule). Self-hosted fonts: IBM Plex Sans, Newsreader (`@fontsource`, no network at runtime). Chart colours in `src/lib/chart.ts`, validated for dark-surface lightness, chroma, colour-vision separation and contrast. |
| UI components | `frontend/src/components/` (design system `ui.tsx`: buttons, tags, tooltip, fields/form groups/“Additional details”, modal, menu, table/sort/pager, skeleton, breadcrumbs, section tabs, stat; `Layout.tsx` sidebar + mobile drawer; `SectionNav.tsx` tabs; `records.tsx` findings/review/evidence/audit; `forms.tsx`; `SpecimenLabel.tsx`) |
| API client | `frontend/src/api/client.ts` (only place `fetch` is called; no mock fallbacks), `types.ts` |
| Routes | `backend/app/routers/` — `core` (home, metrics, assessments, data quality, audit, settings, workspace, export, backups), `catalogue` (organisations, varieties, accessions, batches), `records` (tests, observations, distributions), `evidence` (evidence + attachments, reviews), `imports`, `simulation` (protocol, scenarios, actions) |
| Business logic | `services.py` (snapshots, lineage, completeness, reviews, audit, transactional distributions) |
| Scientific calculations | `intelligence.py`, `quality.py` — pure functions on frozen dataclasses, unit-tested without a database |
| Database access & schema | `models.py`, `database.py`, `bootstrap.py`, `migrations.py` |
| Audit | `services.audit()` → `activity_log` (actor, summary, JSON before/after) |
| Fixtures | `demo_data.py` — only for the demo workspace and the test suite |

## Entities

```
Organization ──< Accession (source_org)          Variety ──< Accession ──< Batch >── Organization (custodian)
Accession ──< Accession (parent: regenerated/derived; lineage root)
Batch ──< GerminationTest      Batch ──< StorageObservation      Batch ──< Distribution >── Organization (recipient)
EvidenceRecord (entity_type, entity_id) → variety | accession | batch | germination_test | storage_observation | distribution
PreservationAction → Variety (+ optional Accession, Batch, ScenarioAnalysis); supporting_records JSON
ScenarioAnalysis → Variety (inputs JSON, result JSON; always hypothetical)
ImportSession (staged rows), ActivityLog (audit), AppSetting (schema version, operator, thresholds)
RescueMission (legacy v1 table, read-only, kept for history)
```

Review provenance (`entered_by`, `review_status` ∈ unverified/reviewed/conflicting, `reviewed_by`, `reviewed_at`) on accessions, tests, observations and evidence. FKs `ON DELETE RESTRICT`; nothing is hard-deleted through the API (archive instead). CHECK constraints on quantities, units, statuses, counts, RH range, review and acquisition enums.

## Schema evolution (non-destructive)

`bootstrap.init_database()` on every start:

- **No database** → create tables, set `schema.version = 2`. **Never inserts fixtures.**
- **v1** → `migrations.migrate_v1_to_v2`: SQLite online backup to `data/backups/<name>-pre-v2-<ts>.db`; `create_all` (new tables); `ALTER TABLE ADD COLUMN` for missing columns; delete v1 `is_demo` rows not referenced by any user row (retained rows reported and stored in `migration.v2.retained_demo`); copy user v1 missions → preservation actions; audit event with the full report. All in one transaction after the backup.
- **v2** → `migrations.migrate_v2_to_v3`: SQLite backup to `data/backups/<name>-pre-v3-<ts>.db`; `create_all` adds `alerts`, `alert_deliveries`, `alert_runs`, `preservation_plans`, `plan_tasks`; `ALTER TABLE ADD COLUMN` adds `batches.review_date` and `batches.passport_token` (unique index); one audit event. v1 databases go v1→v2→v3 in one start with a single (pre-v2) backup.
- **v3** → additive checks only. **Newer** → refuse to start, change nothing.

## Workspaces

`database.py` keeps one engine per workspace URL. The active workspace is process memory and resets to operational on restart. `workspace.py` creates the demo file from fixtures on first entry; *recreate* deletes only the demo file after asserting its resolved path differs from the operational one. Entering/leaving/recreating are audited in the operational database.

## Alerts (v3)

- **Rules** (`alerts.evaluate`) take frozen snapshots of batches, varieties and open tasks plus thresholds and settings, and return candidates with a `dedupe_key` that identifies one event (e.g. `retest_due:batch:6:test:14`, `review_date:batch:3:2026-11-01`). Categories: review_date, retest_due, storage_limits, low_germination, evidence_gap, backup, task_due.
- **Stages**: `reminder_stage(today, due, reminder_days)` → `due_in_{N}d` (inclusive windows), `due_today`, `overdue`, or none. A move to a more urgent stage is a new reminder; never the reverse.
- **Persistence** (`alert_service.run_check`): one `alerts` row per `dedupe_key` (UNIQUE); one `alert_deliveries` row per (alert, channel, stage) (UNIQUE index). Candidates no longer produced → alert auto-resolved by “SEEDFALL” with a note; it reopens only if it was auto-resolved and the condition returns. Dismissed / manually resolved alerts stay closed. Concurrent runs (scheduler + command line + Check now) are serialised in-process by a lock and across processes by the unique constraints (an IntegrityError triggers one retry).
- **Delivery**: in-app = stored delivery (`delivered`), read via `/notifications`. E-mail (optional) = `pending` → `sent` / `retrying` (backoff 5, 15, 60 min) / `failed` after 4 attempts, sent after the alert transaction commits, each attempt committed with its error.
- **Time**: `config.today()` and alert dates use the IANA zone saved in Settings (zoneinfo + tzdata), so Home, assessments and alerts agree on the calendar day.
- **Runs**: every check writes an `alert_runs` row (trigger scheduler/command/manual, counts, errors).

## Guardian, plans and passports (v3)

- `GET /guardian/{variety_id}?batch_id=` is read-only: evidence per batch, backup statement, gaps and risks (from the same rule engine), and suggestions with task kinds and suggested due dates.
- `POST /plans` stores tasks and, for Guardian plans, a server-recomputed snapshot of the review. Tasks: todo → in_progress → done (written outcome + operator) / cancelled. No plan or task endpoint touches inventory.
- `POST /batches/{id}/passport[?rotate=true]` sets a random `passport_token` (`secrets.token_urlsafe(18)`); `GET /passport/{token}` returns only public fields (no custodian, storage location, people, notes or attachments). Rotating invalidates old codes. The token is not authorisation for anything else.

## API (all under `/api`)

Lists: `{items,total,limit,offset}`. Errors: `{"error":{"code","message","details":[{field,message}]}}`. Full OpenAPI at `/docs`.

| Area | Endpoints |
|---|---|
| Core | `GET health, home, metrics, assessments, data-quality, audit` |
| Registry | `GET/POST organizations`, `PATCH organizations/{id}`; `GET/POST varieties`, `GET/PATCH varieties/{id}`; `GET/POST accessions`, `GET/PATCH accessions/{id}`, `POST accessions/{id}/archive`; `GET/POST batches`, `GET/PATCH batches/{id}`, `POST batches/{id}/archive|restore` |
| Evidence | `GET/POST germination-tests`; `GET/POST storage-observations`; `GET evidence`, `POST evidence` (multipart, optional file), `GET evidence/{id}/attachment`; `POST reviews` |
| Ledger | `GET/POST distributions`, `GET distributions/{id}`, `PATCH distributions/{id}/status` |
| Protocol | `POST protocol/run` (read-only; v1 alias `simulations/last-seed`); `GET/POST protocol/scenarios` (POST requires `confirm_hypothetical: true`), `GET protocol/scenarios/{id}` |
| Actions | `GET/POST actions`, `GET/PATCH actions/{id}`, `POST actions/{id}/transition` |
| Alerts | `GET alerts` (status/category/severity/variety/batch/q), `GET alerts/summary`, `GET alerts/runs`, `POST alerts/run`, `GET alerts/{id}`, `POST alerts/{id}/acknowledge|resolve|dismiss|reopen`; `GET notifications`, `POST notifications/read`; `GET/PUT settings/alerts`, `POST settings/alerts/test-email` |
| Guardian & plans | `GET guardian/{variety_id}`; `GET/POST plans`, `GET/PATCH plans/{id}`, `POST plans/{id}/tasks`; `GET plan-tasks`, `PATCH plan-tasks/{id}`; `GET tasks/summary` |
| Passports | `POST batches/{id}/passport`, `GET passport/{token}` |
| Import | `GET imports/targets`, `GET imports/templates/{target}.csv`, `POST imports` (multipart), `POST imports/{id}/validate`, `POST imports/{id}/commit`, `GET imports/{id}/errors.csv`, `GET imports` |
| Settings/data | `GET/PATCH settings/thresholds`, `GET/PUT settings/operator`; `GET workspace`, `POST workspace/demo|operational|demo/reset`; `GET data/status, data/export, data/backups`, `POST data/backups`, `GET data/backups/{name}` |

## Calculation rules

- **Germination %** = normal ÷ tested × 100 (1 dp); undefined unless 0 ≤ normal ≤ tested and tested > 0.
- **Physical holding**: distinct custodian on ≥ 1 active batch (available/reserved/quarantined, quantity > 0).
- **Documented source**: distinct accession *lineage root* (parent chain collapsed) with origin or source organisation recorded and ≥ 1 active batch.
- **Holding coverage**: 0 → no active holding (serious; “not extinct” stated), 1 → single holding (serious), < target → attention, else meets target. Target configurable (default 2).
- **Stock**: per unit, never summed across units.
- **Batch findings**: no test (unknown, never “dead”); latest test below review threshold (historical); test older than review age (re-test, not presumed non-viable); storage above temp/RH heuristics (RH ≠ moisture); missing harvest date, custodian, accession; regeneration review age.
- **Data-quality checks** (`quality.py`): missing provenance; no supporting evidence; near-duplicate identifiers (case/punctuation-insensitive); status/quantity inconsistency; germination counts out of bounds; impossible date order (accession, batch, test, distribution); old tests under policy; temperature without unit. Each finding cites `records:[{type,id,label}]` and a resolution.
- **Measures**: each with formula, population, date basis and missing-value rule; `null` → “Insufficient data”.

## Last Seed Protocol

Baseline = non-archived recorded batches. Threat: batch loss (qty → 0 in the hypothetical copy), stock reduction (%), or planting delay (evaluation date moves; only evidence age is re-evaluated). Intervention, applied to a copy *before* the threat: safety duplicate (same accession → +holding, same source), regeneration (user-assumed yield, untested), recipient return (same accession, unverified), new accession (+source, provenance must later be recorded). Output: per-state holdings, sources, stock, coverage, affected batches, open distributions at risk; warnings with cited records; exact input records; rules; assumptions; uncertainties; data-sufficiency issues; follow-ups; deterministic `LSP-` reference.

## Integrity safeguards

- Protocol run: no writes, `rollback()`; inputs are frozen; tests hash **every table** before/after. Saving recomputes the result server-side and only inserts a `scenario_analyses` row plus an audit event; tests hash all operational tables before/after.
- Distribution completion: single transaction, `UPDATE … WHERE status='pending' AND stock_deducted=0` then `UPDATE batches … WHERE quantity >= q`; either affecting 0 rows rolls back. Tested with 6 concurrent requests.
- Actions: approval requires a named operator; completion requires a written outcome; neither touches inventory.
- Reviews: attributed; editing a reviewed accession resets it to unverified.
- Import: validate-all, commit-once; never overwrite; formulas never evaluated; size/row/encoding/binary checks; rejected rows downloadable.
- Attachments: extension allow-list, magic-byte check, 10 MB limit, random stored name, served as download with `nosniff`, SHA-256 recorded.
- Backups/downloads: filename allow-list regex and resolved-path containment.
- Uniform error envelope; no stack traces; ORM-parameterised queries; CORS restricted to local origins.
