# SEEDFALL — Build Status

**Release state:** v3.0.0 (schema 3: preservation alerts, Last Seed Guardian, preservation plans, QR seed passports; simplified navigation and refined liquid-glass interface) — local, single-user release candidate. Verified on Linux (Python 3.11.15 and 3.13, Node 22, Chromium). The Windows `.bat` launchers have **not** been executed on native Windows. Not production-certified, not independently security-reviewed, no compliance claims.

## v3.0 — smart alerts, Last Seed Guardian, passports

| Area | Implemented |
|---|---|
| Navigation | Home · Seed Registry · Batches · Alerts & Tasks · Germination Tests · Storage · Preservation Plans · Reports · Settings, with tabs for related pages; persistent **Add seed** and notification bell; larger touch targets (40–44 px) |
| Home | Answers *What seeds do we have? / What needs attention? / What should I do next?* from stored records only |
| Add seed | Three-step wizard (variety → accession → batch) with per-step validation; nothing saved until the end; partial failures reported, retry without duplicates |
| Alert engine | 7 rule types (review date, retest due, storage limits, low valid germination, evidence gaps incl. inconsistent test records, no independent backup, task/action due); configurable rules, reminder days (default 30/14/7/1), time zone; every alert stores reason, evidence, rule, uncertainty, records, next step, status, decisions and delivery attempts |
| Duplicate prevention | Unique alert per event, unique notification per stage and channel (database constraints), in-process lock, retry on cross-process conflict; auto-resolve when the condition clears; dismissed/resolved never re-raised for the same event |
| Scheduling | In-server background thread (default hourly, works with no browser open); `python -m app.alert_runner` and `RUN_ALERT_CHECK.bat` for Windows Task Scheduler; every run recorded |
| Notifications | In-app notification centre with unread count and record links; optional SMTP e-mail (environment-only credentials, test button, retries with backoff, failures logged) |
| Last Seed Guardian | Six-step review: select, evidence, rule-based risks with uncertainty, editable suggestions, create plan, loss preview proven read-only |
| Plans & tasks | Plans with owners, due dates, notes, completion outcomes; audited; never change stock |
| QR passports | Random token per batch, read-only public page without private fields, printable label, link rotation |
| Review dates | `batches.review_date` (a reminder, explicitly not an expiry) |
| Liquid glass | Layered glass (tint + internal light + gradient rim), liquid primary buttons, glass secondary buttons, forced-colours and no-blur fallbacks, print styles |
| Migration | v2 → v3 additive with automatic backup; v1 → v3 in one start |

## What changed from v1

| Area | v1 | v2 |
|---|---|---|
| Fresh install | Auto-inserted fictional demo records into the operational database | Empty database; onboarding; fictional records only in a separate, explicitly opened demonstration workspace |
| Upgrade | — | v1 database backed up first, then migrated additively; v1 demo rows removed only where no user record depends on them; user rescue missions copied to preservation actions |
| Registry | Varieties and batches | Varieties · **Accessions** (provenance, lineage, acquisition, collector) · Batches · Custodians |
| Assessment | Single “redundancy” idea | **Physical holdings** vs **documented sources** (lineage-collapsed), each finding citing records and the rule applied |
| Evidence | Germination tests, storage logs | + Evidence documents with local attachments, review status (unverified / reviewed / conflicting) with named reviewer, review queue, data-quality checks citing records |
| Import | None | CSV/XLSX: preview → mapping → per-row validation (all errors) → single-transaction commit → rejected-rows CSV; audited |
| Simulation | Last Seed Simulation | **Last Seed Protocol**: input records, rules, definitions, assumptions, uncertainties, data sufficiency; saving needs explicit confirmation; proven read-only |
| Actions | Rescue missions | Preservation actions: proposed → approved → in progress → completed/cancelled; named approver; written outcome; never touch inventory |
| Metrics | Dashboard charts | Measures page: each with formula, population, date basis, missing-value rule; “Insufficient data” instead of 0 |
| Audit | Activity summaries | Actor + JSON before/after for every change, workspace switch, import, review, threshold change |
| Design | Generic dashboard cards | Editorial layout: paper/ivory, forest green, sage, charcoal, amber, red; serif headings; specimen labels; epistemic tags (recorded/derived/historical/hypothetical/proposed) |

## v2.1 interface redesign (frontend only)

- Dark glass design system: forest-black canvas with one static emerald glow; translucent panels with opaque fallbacks; IBM Plex Sans body and Newsreader headings (self-hosted); text contrast ≥ 4.9:1 on every surface.
- Sidebar in four groups (Workspace, Evidence, Preservation, Management) with icons and labels; related pages combined behind tabs, so every former page is still reachable and no link is dead; accessible mobile drawer (focus contained, Escape closes).
- Overview: four counts from stored records (accessions, batches, valid germination tests, open actions), each linked; onboarding with three ways in; guided “variety first, then accession” flow.
- Tables: search, filters, column sorting and paging on varieties, accessions and batches; detail pages with breadcrumbs and Identity / Provenance / Custody and storage / Evidence / Tests and observations / Distribution history / Audit history sections; secondary actions in an overflow menu.
- Forms: grouped fields, Required/Optional markers, units beside numbers, optional fields under “Additional details”, kept on failed saves, guarded against double submission.
- Last Seed Protocol: five numbered steps; result panels where recorded values are solid and hypothetical ones hatched with a dashed amber edge; per-custodian seed marks; full comparison table; technical details collapsed.
- Charts restyled for the dark theme, each with a legend and a “Show the chart as a table” alternative.
- No backend, database, API or calculation code was changed.

## Implemented

- Workspaces: operational (`data/seedfall.db`) and demonstration (`data/seedfall-demo.db`); switching, recreating the demo (deletes only the demo file after a path check); always operational after restart.
- Schema v2 with non-destructive v1 migration and refusal to open a newer schema.
- Registry CRUD (archive instead of delete), accession lineage, completeness shown as “n of m recommended fields” (not a score).
- Germination tests (counts validated, live % preview), storage observations, distributions with exactly-once stock deduction.
- Evidence records + attachments (allow-list, magic bytes, 10 MB, SHA-256, random stored names, download with `nosniff`).
- Reviews attributed to the operator name; editing a reviewed accession resets it to unverified.
- Data-quality checks (missing provenance, no evidence, near-duplicate identifiers, status/quantity inconsistency, count bounds, impossible date order, stale tests, temperature without unit).
- Configurable thresholds (audited).
- Last Seed Protocol (batch loss / stock reduction / planting delay × none / safety duplicate / regeneration / recipient return / new accession), saved hypothetical analyses, proposal of preservation actions from a result.
- Import of varieties, accessions, batches, germination tests; templates in `docs/import-templates/`.
- Export (JSON of all tables), manual backups, backup download.
- Windows START/STOP launchers (updated comments and backup location).
- Docs: README, ARCHITECTURE, DEMO_SCRIPT, docs/IMPORT_TEMPLATES.md, QA_REPORT.

## Not implemented / out of scope

- Authentication, roles, multi-user editing. The operator name is attribution, **not** a security control.
- In-app restore (restore is a documented manual file copy).
- Import of storage observations, distributions and evidence (forms only).
- Editing/deleting individual tests, observations and evidence after entry (append a corrected record and mark the old one *conflicting*).
- Viability, yield or loss prediction; any genetic-diversity inference; AI features.
- Localisation; units other than g, kg, seeds, packets.
- Browser push notifications (not implemented; in-app and optional e-mail only).
- Per-storage-method or per-species storage limits (limits are global, configurable).
- Phone scanning of QR passports over a network: the app has no login, so it is not exposed beyond this computer by default (see README).
- Importing review dates (the import templates do not include `review_date` yet).

## Known issues

- Windows launchers not executed on Windows (written defensively; CRLF verified).
- Frontend bundle is ~920 kB (258 kB gzip) in one chunk plus self-hosted font files; Vite prints a size advisory. Acceptable for a local app.
- `npm audit --omit=dev` reports a moderate advisory in react-router 6.30.6 (open redirect via backslash in `<Link>`/`useNavigate`; SSR hydration issue). SEEDFALL does no server rendering and navigates only to its own fixed paths; the fix requires the breaking React Router 7 upgrade, not done here. Dev-only advisories (vitest, esbuild, eslint plugin) do not ship in the app.
- E-mail delivery was tested against a simulated SMTP server only; no real mail server was available.
- Wide tables (distributions, tests) scroll horizontally inside their panel on phones and tablets; the page itself does not.
- `backdrop-filter` blur is decorative; browsers without it get the opaque fallback (tested only in Chromium).
- “Today” follows the time zone chosen in Settings (default from `SEEDFALL_TIMEZONE`/`TZ`, else UTC); future-date checks tolerate ±1 day.
- Starlette's TestClient emits one `DeprecationWarning` from anyio in pytest; harmless, pinned versions.
- The v1 legacy `rescue_missions` table is retained read-only for history.
