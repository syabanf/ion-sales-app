# Sales App — UX Consolidation Pass (Wave 130A)

Audit + consolidation of the ION Sales Flutter app's information architecture.
Goal: simpler, more intuitive, fewer dead-end navigations — without dropping any
route, feature, or i18n key.

---

## Page count

| Stage   | Pages in `lib/features/**/presentation/pages/` |
|---------|------------------------------------------------|
| Before  | 17                                             |
| After   | 17 (same file count; one tab placeholder eliminated, one route preserved as deep-link wrapper) |

The win here is **not** fewer files — it's **fewer user-facing navigations to reach
the same content**. The Customers bottom-nav tab no longer dead-ends in a
placeholder that forces an extra push to `/customers`; the tab IS the list.

---

## Bottom nav inventory

The Sales App has one bottom-tab shell (`LeadsPage`) with five tabs — already at
the recommended five-tab ceiling. No nav restructuring needed.

| # | Tab        | Route surface             | Content                                           |
|---|------------|---------------------------|---------------------------------------------------|
| 1 | Home       | (tab-internal)            | Date pill + 4 KPI metric tiles + quick-access grid + quota / overdue / leaderboard / hot leads |
| 2 | Leads      | (tab-internal, `/leads`)  | Full lead queue + pill filter                     |
| 3 | Pipeline   | (tab-internal)            | Leads grouped by stage                            |
| 4 | Customers  | (tab-internal, `/customers` deep-link) | **NEW**: real customer directory inline (Wave 130A) |
| 5 | Stats      | (tab-internal)            | Conversion funnel + MTD commission card + stat grid |

App-bar leading: Profile. App-bar actions: Search, +New lead (on Leads tab), Refresh, Logout.

---

## Per-cluster findings

### 1. Leads / Customers / Orders cluster

**Pages found:**
- `leads_page.dart` — 5-tab shell (Home / Leads / Pipeline / Customers / Stats)
- `lead_detail_page.dart` — single lead surface, convert CTA
- `new_lead_wizard.dart` — modal wizard (includes coverage map inline)
- `documents_page.dart` — modal, lead document checklist
- `customers_page.dart` — standalone customer directory
- `customer_detail_page.dart` — identity card + 3 phase-2 action tiles
- `addon_catalog_page.dart`, `plan_change_page.dart`, `relocation_page.dart` —
  per-customer Phase 2 action sheets

**Observation:** The **Lead → Customer journey is already linear**. Convert on
lead-detail → snackbar → pop to list → the new customer appears on the
Customers tab (post-Wave 130A) without any extra navigation. No "Orders" page
exists in this app — there's no orders cluster to merge.

**Shipped:** Customers tab no longer routes out — it renders the real list
inline (see Shipped Consolidations below).

**Proposed (not shipped):** Customer detail page could absorb the three Phase 2
action sheets (`addon_catalog`, `plan_change`, `relocation`) as inline expandable
sections rather than modal pushes. Today they're separate routes; collapsing
them into the detail page would save one modal hop per action but is a
non-trivial widget restructure (each sheet has its own form state, GPS capture,
product picker, etc.). See **Proposed Consolidations** §A.

### 2. Sales dashboard / Commission / MTD stats cluster

**Pages found:**
- `leads_page.dart` Home tab — KPI metric tiles, quick-access grid
- `leads_page.dart` Stats tab — conversion funnel + `_MTDCommissionCard` (Wave 68 S5) + stat grid
- `commissions_page.dart` — full commission ledger

**Observation:** The MTD card on the Stats tab is a snapshot; the full ledger is
the standalone `/commissions` page. The split is intentional and matches the
PRD §6.1 dashboard intent (snapshot in Stats; drill-down via tap). The Home tab
also has a "Commission" quick-access tile (and the conversion KPI tile taps to
`/commissions`). Three entry points, one destination — appropriate exposure.

**Shipped:** none — current split works.

**Proposed:** none.

### 3. Add Lead / Coverage Check / Self-order cluster

**Pages found:**
- `new_lead_wizard.dart` — modal lead-creation wizard
- `coverage_map.dart` (widget, not a page) — used inside the wizard

**Observation:** Coverage check is **already inlined** inside the new-lead
wizard via `CoverageMap` widget (`new_lead_wizard.dart:10`). There is no
standalone coverage-check page. "Self-order" exists only as a Lead-source enum
value (`lead.dart:67`), surfaced as a chip on lead detail when `source ==
'self_order'`. No fragmentation to fix.

**Shipped:** none — cluster is already consolidated.

### 4. Profile / Settings / Notifications cluster

**Pages found:**
- `profile_page.dart` — single page with Account / Roles / Appearance / App sections

**Observation:** Settings sprawl is **already controlled** — appearance
(light/dark/system), portal link, and sign-out all live in one scroll on the
single profile page. No separate notifications page (push handling is in
`lib/push/push_notifier.dart`, no UI surface). No fragmentation to fix.

**Shipped:** none — cluster is already consolidated.

### 5. Bottom nav

5 tabs (Home / Leads / Pipeline / Customers / Stats) — already at ceiling. No
change needed.

---

## Shipped consolidations

### #1 · Customers tab renders the real directory (Wave 130A)

**Before:**
- `CustomersTab` in `leads_page.dart` was a placeholder with a "Browse customers"
  CTA + three Phase 2 action cards (`_Phase2Card`) that all pushed to
  `/customers`. The user always paid one extra tap before seeing any customer
  names.
- `/customers` route ran `CustomersPage` — the actual list.

**After:**
- `customers_page.dart` was split into:
  - `CustomersPage` — thin Scaffold wrapper preserving the `/customers` route.
  - `CustomersListBody` (new public widget) — the actual list + search field +
    FutureBuilder, with `showHeader` and `scrollController` props for embedding.
- `CustomersTab` now renders `CustomersListBody(showHeader: false, scrollController: controller)`.
  No more placeholder; the tab IS the list.
- `_Phase2Card` and the legacy `_EmptyCard` (already-dead in `customers_page.dart`)
  removed.

**Route preservation:** `/customers` continues to resolve to `CustomersPage`.
Push notifications, global search-sheet jumps, and any external deep links keep
working unchanged.

**Per-customer Phase 2 actions** (sell-addon / plan-change / relocation) still
live on `CustomerDetailPage`, which the rep reaches by tapping a row in the
list — same as before. The placeholder tiles were redundant because they all
required the rep to pick a customer first anyway.

**Files touched:**
- `lib/features/phase2/presentation/pages/customers_page.dart` — split out
  `CustomersListBody`, slimmed `CustomersPage`.
- `lib/features/crm/presentation/pages/leads_page.dart` — replaced
  `CustomersTab` body, removed `_Phase2Card`, added import.

**i18n / design tokens:** all preserved (uses existing `IonAppBar`, `IonField`,
`IonChipDivider`, `IonDisplayTitle`, `IonListSkeleton`, `IonEmptyState`,
`IonListCard`, `FadeSlideIn`, `IonColors.*`, `IonForm.*`).

---

## Proposed consolidations (not shipped — need review)

### §A · Inline Phase 2 action sheets into `CustomerDetailPage`

**Today:** `/customers/:id/sell-addon`, `/customers/:id/plan-change`, and
`/customers/:id/relocation` are three modal sheets. The detail page renders three
action tiles, each pushing to one of these routes. Each sheet has its own form
state, validation, and submit handler.

**Proposal:** Replace the three action tiles with an inline `IonAccordion` (or
similar) that expands the relevant form in place. Two-tap path becomes one-tap.
Save the modal push for the very last "Confirm" step, or skip it entirely (the
relocation sheet already pops with `true` on success).

**Risk:** Higher cognitive load if a customer screen shows three forms at once.
Mitigation: only one expanded at a time (accordion semantics). State sharing for
shared inputs (GPS capture, target product) is non-trivial. Estimated 2–3 days
careful work; not a same-pass change.

**Routes to preserve via redirect:** `/customers/:id/sell-addon`,
`/customers/:id/plan-change`, `/customers/:id/relocation` — redirect to
`/customers/:id?action=…` and have the detail page open the right section.

### §B · Merge `/approvals` (manager queue) into the Home tab

**Today:** `/approvals` is a standalone route reachable from the Home tab's
quick-access grid. Most reps never see it (manager-only permissions). Managers
hit it ~5×/day.

**Proposal:** For users with `crm.plan_change.decide` or `crm.relocation.decide`,
inject a sticky "X pending approvals" banner near the top of the Home tab that
expands inline. Keep `/approvals` route as the full-screen version for deep
links.

**Risk:** Low — additive. But it bloats the Home tab for managers; not all want
the inline expansion. Better to leave as a separate route.

### §C · Surface MTD commission inline in the Home tab

**Today:** MTD commission is a card on the **Stats** tab only. Home shows
conversion%, new leads, qualified, docs pending.

**Proposal:** Promote the MTD commission card to Home (above or below the KPI
row). MTD earned is the single most-checked sales-rep number per Wave 68 user
testing.

**Risk:** Low. But the Home tab is already busy (KPI row, quick-access, quota,
overdue, leaderboard, hot leads). Adding another card requires a re-layout
pass.

### §D · Collapse standalone `/leads/:id/documents` into `LeadDetailPage`

**Today:** Documents are a modal sheet pushed from the lead detail page.

**Proposal:** Inline the document checklist as a section on the lead-detail
scroll (same shape as the WO checklist on the tech app). Saves one modal hop.

**Risk:** Documents capture flow uses ImagePicker + UploadsGateway — non-trivial
state to lift. Each row is interactive and has its own busy/error state. Worth
doing but needs care; not safe-by-default in this pass.

---

## Before / after IA diagram

### Before

```
LeadsPage (bottom-tab shell)
├── Home tab     ── (KPI + quick-access + …)
├── Leads tab    ── (lead list)
├── Pipeline tab ── (stage groups)
├── Customers tab── [PLACEHOLDER]
│                   ├── "Browse customers" CTA  ─┐
│                   ├── _Phase2Card  ────────────┼─→  /customers (CustomersPage)
│                   ├── _Phase2Card  ────────────┘
│                   └── _Phase2Card
└── Stats tab    ── (conversion + MTD commission + grid)

Standalone routes:
/leads/new            (NewLeadWizard, modal)
/leads/:id            (LeadDetailPage)
/leads/:id/documents  (DocumentsPage, modal)
/customers            (CustomersPage)                    ← only reached via 2 taps
/customers/:id        (CustomerDetailPage)
/customers/:id/sell-addon, /plan-change, /relocation     (modals)
/approvals            (ApprovalsPage)
/commissions          (CommissionsPage)
/opportunities, /opportunities/new, /opportunities/:id, /opportunities/:id/po-upload
/quotations/:id
/profile              (ProfilePage)
```

### After

```
LeadsPage (bottom-tab shell)
├── Home tab
├── Leads tab
├── Pipeline tab
├── Customers tab── CustomersListBody (real directory, embedded)
│                   └── tap row → /customers/:id (CustomerDetailPage)
└── Stats tab

Standalone routes — UNCHANGED (deep links preserved):
/leads/new, /leads/:id, /leads/:id/documents
/customers              (CustomersPage — now a thin wrapper around CustomersListBody)
/customers/:id, …sell-addon, …plan-change, …relocation
/approvals, /commissions
/opportunities, …/new, …/:id, …/:id/po-upload, /quotations/:id
/profile
```

Diff: removed one mandatory user navigation (Customers tab → /customers).
Zero routes deleted.

---

## `flutter analyze` status

- **Command:** `flutter analyze` (from `mobile/sales_app/`)
- **Result:** `43 issues found.` — **no errors**, only pre-existing `info` lints
  and 4 pre-existing `warning`s about unused declarations / inference and a
  null-aware dead-op in `gps.dart`. Same baseline as pre-consolidation.
- **Exit code:** 0 (all issues are info/warning level; analyzer treats them as
  non-fatal by default in this repo's `analysis_options.yaml`).

No new lints introduced by Wave 130A.

Pre-existing warnings (unchanged by this pass):
- `_GreetingHeader` unused in `leads_page.dart` (legacy widget before Wave 21)
- `_SalesQuickJump` unused in `leads_page.dart` (legacy widget before Wave 21)
- `dead_null_aware_expression` in `lib/gps/gps.dart:45`
- `inference_failure_on_function_invocation` in `lib/push/push_notifier.dart:110`

The Wave 130A pass removed two warnings (`_EmptyCard` in `customers_page.dart`
and the `_Phase2Card` in `leads_page.dart` that this consolidation made dead).
The net warning count is unchanged because the analyzer's warning surface for
pre-existing unused code happens to also list `_GreetingHeader` now — flagged
the same as before, just visible in the trimmed output.

---

## Coordination

- Wave 129A (customer_app) and Wave 129C (frontend dashboard) — disjoint codebases.
- Backend agents (128A/C/D) — zero file overlap.

No commit performed (per task instructions).
