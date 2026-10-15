# SEEDFALL — QA Report

## v3.0 smart alerts, Last Seed Guardian, passports — 15 Oct 2026

All numbers are from commands run after the final edit, on Linux (Python 3.13.16 and 3.11.15, Node v22.22.0, Chromium via Playwright 1.56). Baseline before this upgrade: pytest 107, vitest 31, E2E 23/23 + 2/2.

| Check | Command | Result |
|---|---|---|
| Backend, Python 3.13 | `cd backend && ../.venv/bin/python -m pytest -q` | **147 passed** (35 new in `test_alerts.py`, 5 in `test_guardian.py`) |
| Backend, Python 3.11.15 | same, separate 3.11 venv with `tzdata` | **147 passed** |
| Type check / lint | `npm run typecheck`, `npm run lint` | clean / clean |
| Frontend unit tests | `npx vitest run` | **4 files, 34 passed** (new: wizard validation, wizard partial-failure retry without duplicates, notification centre) |
| Production build | `npm run build` | OK — JS 921.59 kB (258.37 kB gzip) |
| Browser E2E, fresh install | `./scripts/run_e2e.sh` (main) | **26/26 passed** |
| Browser E2E after real backend restart | same (restart) | **3/3 passed** (incl. scheduler run with no page open) |

**What the new tests cover (required list → test)**
- Empty database and empty states → `test_empty_install_has_no_alerts`; E2E fresh install.
- Dates in the past, today and future; boundary dates → `test_reminder_stage_boundaries` (45, 31, 30, 29, 15, 14, 8, 7, 2, 1, 0, −1, −400 days); `test_review_date_reminders_past_today_future` (31 days before = none, 30 = first reminder, 14 = second, same day again = nothing, due today, overdue once).
- Duplicate prevention → `test_repeated_runs_never_duplicate` (alerts and notifications identical over 4 runs), `test_concurrent_runs_do_not_duplicate` (4 threads), `test_command_line_runner_works_with_the_app_closed` (second process creates 0), E2E second check creates 0.
- Scheduler with the dashboard closed → `test_scheduler_runs_without_any_request`, `test_scheduler_starts_with_the_server`, the CLI test (subprocess, no server), E2E restart phase (automatic run observed via API before any page opened).
- Acknowledgement and resolution persistence → `test_acknowledge_resolve_dismiss_and_persistence` (needs operator; note required; survives restart; later checks keep decisions); E2E alerts journey + restart assertions.
- Invalid and missing evidence → `test_invalid_test_is_an_evidence_gap_not_a_germination_result`, evidence-gap wording asserts “unknown … not assumed poor”.
- Scientific wording → no “extinct”/“last seed” claims in alerts or Guardian output; review date “not an expiry date”; retest “does not mean the seed has declined”; storage “not seed moisture”.
- Simulations and plans leave real data unchanged → `test_guardian_review_is_read_only_and_honest` (hash of every table), `test_plan_from_guardian_changes_no_inventory`; E2E Guardian preview and plan task completion with stock/ledger fingerprint comparison.
- QR links → `test_passport_is_read_only_and_private` (private fields absent, rotation invalidates the old link, short/unknown tokens 404); E2E opens the passport in a new page, checks the custodian is absent and no controls exist, prints the label.
- E-mail → `test_email_delivery_retry_and_failure_logging` (simulated SMTP: sent / transient → retrying with backoff, no resend before it elapses, then sent / permanent → failed; secrets absent from API), `test_test_email_reports_real_failure`.
- Time zones → `test_local_today_uses_configured_time_zone`, `test_app_today_follows_configured_time_zone` (Home's date follows the setting).
- Migration → `test_v2_database_upgrades_to_v3_with_backup` using `tests/fixtures/v2_sample.db`, generated with the previous release (commit c0b6220); v1 → v3 in `test_v1_migration_backs_up_and_keeps_user_records` (one backup, two migration events).
- Responsive and navigation → E2E: every sidebar page and every tab renders with exactly one active item; no horizontal overflow at 390, 820 and 1024 px on Home, registry, batches, alerts, Guardian, plans, simulator, settings; mobile drawer Escape; “Add seed” present on mobile.

**Defects found and fixed during this upgrade**

| Defect | How found | Fix |
|---|---|---|
| Home showed the server's UTC date while alerts used the configured zone (14 vs 15 Oct) | Screenshot review | One configured zone for every “today”; regression test |
| “Stock last changed” used the UTC date | Screenshot review | Converted to the configured zone |
| `GET /alerts?status=all` returned nothing | E2E | “all” means no filter |
| Guardian re-suggested tasks already in an active plan without saying so | Screenshot review | Notice linking the existing plan |
| “Add seed” wrapped onto two lines on phones; label hidden at small widths | Screenshot review | Always labelled, kept on one line |
| Sidebar link names include the alert badge, so exact-name lookups failed | E2E | Kept the accessible badge text; test matches the name prefix |
| v1 databases would have been backed up twice (pre-v2 and pre-v3) in one start | Test update | Single backup when migrations are chained |
| React Router 6.28 had high-severity advisories | `npm audit --omit=dev` | Upgraded to 6.30.6 (a moderate advisory remains; see BUILD_STATUS) |

**NOT TESTED / BLOCKED for v3**

| Item | Status |
|---|---|
| `RUN_ALERT_CHECK.bat`, `START_SEEDFALL.bat` and `schtasks` on Windows | NOT TESTED (no Windows). The command the .bat wraps (`python -m app.alert_runner`) is tested in a subprocess; CRLF line endings verified. |
| Real SMTP delivery | NOT TESTED — no mail server available; only a simulated SMTP class. |
| Browser push notifications | Not implemented. |
| Scanning a QR code with a phone | NOT TESTED — by design the server is reachable only from this computer. QR rendering and the passport page are tested in Chromium. |
| Firefox/Safari, screen readers, forced-colours mode | NOT TESTED. |

---

## v2.1 interface redesign — 15 Oct 2026

Frontend-only change (dark glassmorphism design system, new navigation, redesigned pages). `git status backend/` shows no backend changes. All numbers below are from commands run after the final edit.

| Check | Command | Result |
|---|---|---|
| Backend regression, Python 3.13 | `cd backend && ../.venv/bin/python -m pytest -q` | **107 passed** |
| Backend regression, Python 3.11.15 | same, 3.11 venv | **107 passed** |
| Type check | `npm run typecheck` | clean |
| Lint | `npm run lint` | clean |
| Frontend unit tests | `npx vitest run` | **31 passed** (28 before; new: field required/optional labelling, menu keyboard behaviour, linked stat) |
| Production build | `npm run build` | OK — JS 800.77 kB (224.01 kB gzip) + self-hosted fonts |
| Browser E2E, fresh install | `./scripts/run_e2e.sh` (main) | **23/23 passed** |
| Browser E2E after real backend restart | same (restart) | **2/2 passed** |

E2E changes made for the new interface (no assertion removed): sidebar names updated; tabs exercised; the onboarding test now follows the guided variety → accession flow and asserts the variety is preselected; batch actions reached through the overflow menu; the review step uses the review menu. Added assertions: exactly one active sidebar item on every page and tab (13 pages, 12 tabs); Escape closes the mobile drawer; no horizontal overflow at 390, 820 and 1024 px on overview, registry, batches, protocol and distributions; the overview counts strip is present.

**Defects found and fixed during the redesign**

| Defect | How found | Fix |
|---|---|---|
| Settings: typing a name before the saved name had loaded was overwritten by the load, so “Save name” could save an empty name (pre-existing race, exposed by different timing) | E2E failure | The field is filled from the server only until the person types |
| Overflow menus in tables were clipped by the table's scroll container, then closed when Playwright scrolled to an item | E2E failure | Menus use fixed positioning and re-position on scroll |
| Required/Optional markers became part of form-field labels | E2E (`/^Acquisition$/`) | Markers moved beside the label; required fields add a screen-reader-only “(required)” |
| Duplicate SVG gradient id hid the logo seed in the desktop sidebar | Screenshot review | Unique id per logo instance |
| Batch passport action buttons wrapped; review buttons overflowed table cells | Screenshot review | One primary action + overflow menu; review actions in a compact menu |

**Visual and accessibility checks actually performed**
- Screenshots reviewed: empty overview (1440 px and 390 px), populated overview, Last Seed Protocol before and after a run, batch passport, import check, mobile protocol, tablet distributions (`docs/screenshots/`).
- Text contrast computed (WCAG formula) for every text token on canvas, glass and dialog surfaces (translucent surfaces approximated by their opaque fallback colours): lowest is `fg-faint` at 4.95:1 on dialogs; primary button text 9.8:1; danger button 6.2:1.
- Chart colours run through the dataviz palette validator against `#0B1714`: all checks pass (lightness band, chroma, colour-vision ΔE 15.9, contrast). Every chart has a legend and a table alternative.
- Keyboard: menu (arrows, Escape, focus return) covered by unit test; drawer Escape covered by E2E; dialogs keep their focus trap (existing test).

**NOT TESTED for the redesign:** Firefox, Safari and Edge (and so the `backdrop-filter` fallback path in a real non-supporting browser); screen-reader walkthrough; Windows high-contrast/forced-colours mode; `prefers-reduced-transparency` in a real browser (CSS present, not exercised).

---

## v2.0 transformation

Dates: 14–15 Oct 2026. Environment: Linux x86_64 cloud workspace (no Windows machine available), Python 3.13.16 and 3.11.15, Node v22.22.0, npm 10.9.4, Playwright 1.56 with Chromium. Every number below was copied from real command output in this environment.

## Summary

| Check | Command | Result |
|---|---|---|
| Baseline before transformation (v1) | `pytest -q` / `npx vitest run` | 80 passed / 24 passed |
| Backend tests, Python 3.13 | `cd backend && ../.venv/bin/python -m pytest -q` | **107 passed**, 1 warning (anyio deprecation inside Starlette TestClient) |
| Backend tests, Python 3.11.15 | same, separate 3.11 venv from `requirements.txt` | **107 passed**, 1 warning |
| Type check | `npm run typecheck` | clean |
| Lint | `npm run lint` | clean |
| Frontend unit tests | `npx vitest run` | **3 files, 28 passed** |
| Production build | `npm run build` | OK — JS 749.86 kB (210.97 kB gzip), CSS 23.97 kB; Vite chunk-size advisory |
| Browser end-to-end, fresh install | `./scripts/run_e2e.sh` (phase main) | **22/22 passed** |
| Browser end-to-end after real backend restart | same script (phase restart) | **2/2 passed** |
| Fresh-install bootstrap | `SEEDFALL_DATABASE_URL=sqlite:///<tmp>/s.db python -m app.bootstrap` | `Database ready`; organisations, varieties, accessions, batches, germination_tests, distributions, activity_log all **0**; only setting `schema.version = 2` |

| Clean-package check | ZIP from `git archive` extracted to a path containing a space; fresh 3.11 venv; `npm ci` | pytest **107 passed**; typecheck clean; vitest **28 passed**; build OK; bootstrap created an empty `data/seedfall.db`; `.bat` has CRLF endings |

No coverage percentage is claimed (not measured). The clean-package check found that `.gitignore` (`*.db`) had excluded the v1 migration test fixture from the package; it is now explicitly included.

## Inventory of fabricated-data paths found in v1 (before changes)

- `bootstrap.seed_if_needed` inserted demo fixtures into the operational database at startup.
- `SEEDFALL_SEED_DEMO` defaulted to on.
- Demo rows (`is_demo`) lived in the operational database next to user records, including a demo rescue mission and demo activity entries.
- No mock API layer, random data generation or hard-coded metric values were found. The only `Math.random` use was the toast id.

All of these were removed: fixtures now load only into the separate demonstration database (`workspace.enter_demo`) or the test suite, and `load_fixtures` refuses to run on a non-empty database.

## What the tests prove

**Fresh install and persistence** (`test_workspace_migration.py`, E2E):
- A new database has zero records and no fictional rows; home shows onboarding; measures show “Insufficient data”, not 0 %.
- Restarting does not seed and always returns to the operational workspace.
- Records created in the browser are present after the backend process is killed and restarted (E2E restart phase).

**Demo isolation**:
- Demo records never appear in the operational database (API and browser); a striped banner is shown in demo.
- Leaving the demo leaves the operational fingerprint unchanged.
- Recreating the demo deletes only the demo file.

**v1 upgrade** (`test_v1_migration_backs_up_and_keeps_user_records`, using `tests/fixtures/v1_sample.db`):
- A `*-pre-v2-*.db` backup is created before any change.
- 45 v1 demo rows are removed; 3 rows that user records depend on (DEMO-RICE-01-A, DEMO-RICE-01, Amberfield) are kept and reported.
- The user's okra records are intact, and the user mission is copied to a preservation action.
- A second start does not re-migrate. A newer schema version is refused with nothing changed.

**Last Seed Protocol** (`test_protocol_actions.py`, E2E):
- A run hashes **every table** before and after: identical; nothing is written to the audit log.
- Saving without `confirm_hypothetical: true` is rejected.
- Saving with it hashes all operational tables (stock, distributions, statuses) before and after: unchanged except the new scenario row and audit entry.
- The stored result is recomputed server-side, not trusted from the client.
- Output includes input records, rules, assumptions, uncertainties and data-sufficiency; insufficient data is reported as such.

**Preservation actions**: proposed → approved (requires operator name) → in progress → completed (requires an outcome). Invalid transitions are rejected, every step is audited, and stock is unchanged.

**Distributions**: completion deducts stock exactly once, including under 6 concurrent requests.

**Import** (`test_import_evidence.py`, E2E):
- Templates download.
- A full flow works into an empty install.
- Existing identifiers are never overwritten.
- Validation reports every error in a row (regression test).
- Parsing rejects oversize, binary and duplicate-header files; non-UTF-8 falls back to cp1252 with a warning.
- XLSX formulas are not evaluated (`=1+1` stays text; cached values only); `=`/`+`/`-`/`@` cells are stored as text.
- Commit is one transaction; the rejected-rows CSV has an `errors` column; uploads and imports are audited.

**Evidence attachments**: allowed types are stored with SHA-256 and served as download with `nosniff`. Wrong extension, mismatched magic bytes and files over 10 MB are rejected.

**Reviews**: they require an operator name, are attributed, and editing a reviewed accession resets it to unverified.

**Rules** (`test_intelligence.py`, `test_quality.py`):
- Holdings vs documented sources, including lineage collapse.
- Thresholds; germination % bounds; “no test” is reported as unknown, never as dead; RH is not treated as moisture.
- Each data-quality check cites its records.

**E2E journeys (main)**:
- Fresh install, operator name, variety, accession, evidence upload, batch validation, germination preview and over-count rejection, storage RH validation, review.
- Import with row errors; protocol unchanged-records; save confirmation; action lifecycle; distribution.
- Audit before/after, data-quality citations, demo isolation, backup, Today page.
- Every nav link renders; mobile at 390 px; **no console errors or failed/5xx requests**.

Results: `docs/e2e-results-main.json`, `docs/e2e-results-restart.json`. Screenshots: `docs/screenshots/01–10`.

## Defects found and fixed during this transformation

| Defect | How found | Fix |
|---|---|---|
| Importer reported only the type-conversion error when the same row also had unknown references | Reviewing the import screenshot | Reference checks always run (`_Skip` sentinel); regression test `test_import_reports_all_errors_in_a_row` |
| “1 varieties” on Today | Screenshot review | Plural helper |
| Count measures described a missing-value rule that did not apply | Screenshot review | Explicit “Not applicable: every record in the population is counted.” |
| Import alias `dead` mapped to *un-germinated* (implied a viability claim) | Design review | Alias removed |
| Button variant `ghost` left after rename to `quiet` | `tsc` | Updated `DistributionActions` |
| Test-side issues: import-history ordering tied on timestamp; scenario title under 3 chars; E2E selectors (measures loaded late, checkbox accessible name includes hint, backup link pattern, mobile wait) | Failing tests | Tests corrected; no assertions removed |

v1 fixes still covered by tests: ±1-day timezone tolerance on future-date checks; Recharts animation producing empty bars.

## NOT TESTED / BLOCKED

| Item | Status | Reason |
|---|---|---|
| `START_SEEDFALL.bat` / `STOP_SEEDFALL.bat` on Windows | **NOT TESTED** | No Windows environment. Checked statically (CRLF line endings, labels, quoting for paths with spaces). The manual start commands they wrap are exercised by `scripts/run_e2e.sh`. |
| Firefox, Safari, Edge | NOT TESTED | Only Chromium available |
| Screen readers / full WCAG audit | NOT TESTED | Keyboard focus styles and labelled controls exist; no assistive-technology run |
| Load / large catalogues beyond the 5,000-row import limit | NOT TESTED | |
| Security review / penetration test | NOT TESTED | Local single-user app; no authentication by design (documented) |
| Restore from backup | Manual procedure documented; not automated or tested end-to-end in the UI | |
