# Welcome and Guided Tours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-run language, appearance, login, and home flow followed by independent contextual tours that operate the real controls of each supported application module.

**Architecture:** `WelcomeGate` selects the first-run flow or `HomeScreen`; versioned local preferences and a single controller coordinate independent named `ShowcaseView` scopes. Every module owns its keys and sequence under `lib/welcome/<module>/`, while existing screens retain navigation and business logic.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, Provider, SharedPreferences, `introduction_screen 5.0.1`, `showcaseview 5.1.0`, Flutter ARB localization.

**Spec:** `docs/superpowers/specs/2026-10-07-welcome-guided-tours-design.md`

## Global Constraints

- Flutter floor is `>=3.44.0`; Dart range is `>=3.12.0 <4.0.0`.
- All new files, types, methods, variables, keys, and comments use English names.
- Every visible string comes from `context.l10n` with English camelCase keys prefixed by `welcome`.
- Guide state is local-only and uses versioned SharedPreferences keys; it is never synchronized through MGWS.
- Tours operate real mounted controls; do not add screenshots, fake screens, simulated data, or duplicate business logic.
- Safe actions may execute; destructive, commercial, stock-changing, credential-revoking, and other consequential actions remain informational.
- Optional features are never enabled automatically. Tours branch from the current configuration and user choice.
- Only one tour can be active. Route disposal, logout, and session changes dismiss without marking completion.
- Manual Help starts only the current screen's tour. Skip or finish marks only that tour complete.
- Exclude CalDAV, log viewer, shared barcode/QR scanner, RFID, AI, and updater tours.
- Do not create automated tests unless the user explicitly changes the repository rule. Use the verification commands and manual acceptance cases in this plan.
- Update current documentation in `lib/doc` with implemented behavior only; do not document future phases as available.
- Do not commit unless the user explicitly asks. If commits are later requested, use English title, blank line, then English `-` bullet lines.

## Review Focus

The following high-risk behaviors require explicit manual acceptance in their owning tasks because project policy currently excludes new automated tests:

1. Corrupt or unavailable SharedPreferences must fall back to showing the overview without trapping startup.
2. Rapid navigation, resize, or logout while an overlay is active must not use a disposed context or leave an invisible interaction barrier.
3. Conditional targets absent because of role, breakpoint, entity type, or MGWS state must be filtered rather than crash the tour.
4. Failed or dismissed login must not incorrectly complete the login tour; successful login must resume the home tour exactly once.
5. Manual replay of one completed module must not reset, start, or alter any other module.

---

## Delivery Phases

This specification spans several independent subsystems. Execute it as five releasable phases:

1. **Foundation and first run:** Tasks 1-8.
2. **Catalog tours:** Tasks 9-10.
3. **Stock and point-of-sale tours:** Tasks 11-12.
4. **Commerce and people tours:** Tasks 13-18.
5. **Analysis, settings, documentation, and final verification:** Tasks 19-23.

Stop at each phase boundary for a diff review and supported-platform build. Do not begin a later phase while the current phase has analyzer or build failures.

### Task 1: Add and prove the overlay dependency

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`

**Interfaces:**
- Consumes: Flutter `>=3.44.0` and existing `introduction_screen 5.0.1` dependency.
- Produces: `showcaseview 5.1.0` available to all guided screens.

- [ ] Add `showcaseview: ^5.1.0` next to `introduction_screen` in `pubspec.yaml`.
- [ ] Run `flutter pub get`.
  - Expected: dependency resolution succeeds and locks `showcaseview 5.1.0` without downgrading `introduction_screen`.
- [ ] Run `flutter analyze`.
  - Expected: `No issues found!`
- [ ] Run `flutter build linux --debug` and `flutter build apk --debug`.
  - Expected: both builds exit successfully; existing Gradle deprecation warnings are non-blocking.

### Task 2: Define guide identity and local persistence

**Files:**
- Create: `lib/welcome/welcome_tour_ids.dart`
- Create: `lib/welcome/welcome_preferences.dart`

**Interfaces:**
- Consumes: `SharedPreferences`.
- Produces:
  - `enum WelcomeTourId { overview, login, home, productManagement, productCreation, inventory, cashier, orders, customers, suppliers, loyalty, coupons, reports, dashboard, employees, settings }`
  - `String WelcomeTourId.preferenceKey`, returning `welcome.v1.<id>.completed`.
  - `class WelcomePreferences`
  - `Future<bool> isCompleted(WelcomeTourId tourId)`
  - `Future<void> markCompleted(WelcomeTourId tourId)`
  - `Future<void> reset(WelcomeTourId tourId)`
  - `Future<void> resetAll()`
  - `Future<Map<WelcomeTourId, bool>> completionSnapshot()`

- [ ] Implement the exact enum and versioned key mapping; do not include excluded modules.
- [ ] Implement `WelcomePreferences` with an injectable optional `SharedPreferences` constructor argument and lazy `SharedPreferences.getInstance()` fallback.
- [ ] Catch read/write failures, log through `app_logger.dart`, return `false` for failed reads, and never block startup.
- [ ] Run `dart format lib/welcome/welcome_tour_ids.dart lib/welcome/welcome_preferences.dart`.
- [ ] Run `flutter analyze`.
  - Expected: no issues.
- [ ] Manually use a temporary debugger expression or app invocation to confirm all keys begin with `welcome.v1.` and `resetAll()` removes only the known guide keys; do not leave debug code in the tree.

### Task 3: Implement the single-tour coordinator

**Files:**
- Create: `lib/welcome/welcome_tour_controller.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `WelcomePreferences`, `WelcomeTourId`, named `ShowcaseView` scopes.
- Produces:
  - `enum WelcomeTourStartMode { automatic, manual }`
  - `enum WelcomeTourEndReason { finished, skipped, dismissed, navigation, unavailable }`
  - `class WelcomeTourCheckpoint { WelcomeTourId tourId; String stepId; }`
  - `class WelcomeTourController extends ChangeNotifier`
  - `WelcomeTourId? get activeTour`
  - `WelcomeTourId? get requestedManualTour`
  - `WelcomeTourCheckpoint? get pendingCheckpoint`
  - `Future<bool> shouldStartAutomatically(WelcomeTourId tourId)`
  - `bool begin(WelcomeTourId tourId, {required WelcomeTourStartMode mode})`
  - `void requestManualStart(WelcomeTourId tourId)`
  - `WelcomeTourId? takeManualStartRequest()`
  - `void saveCheckpoint(WelcomeTourCheckpoint checkpoint)`
  - `WelcomeTourCheckpoint? takeCheckpoint(WelcomeTourId tourId)`
  - `Future<void> end(WelcomeTourEndReason reason)`
  - `void dismissForSessionChange()`

- [ ] Implement the controller so `begin` returns `false` while another tour is active.
- [ ] Implement one pending manual-start request: Settings publishes it, Home consumes it once and navigates through existing section callbacks.
- [ ] Make `end` persist only `finished` and `skipped`; all other reasons clear runtime state without marking completion.
- [ ] Register a single `ChangeNotifierProvider<WelcomeTourController>` in `main.dart`, constructed from one `WelcomePreferences` instance.
- [ ] Ensure `dismissForSessionChange()` clears checkpoints and active runtime state without resetting persisted completion.
- [ ] Run formatting and `flutter analyze`.
- [ ] Manually verify repeated `begin` calls cannot activate two tours and manual begin ignores completed state while automatic checks do not.

### Task 4: Build welcome, language, and appearance pages

**Files:**
- Create: `lib/welcome/welcome.gui.dart`
- Create: `lib/welcome/welcome.code.dart`
- Create: `lib/welcome/widgets/welcome_language_page.dart`
- Create: `lib/welcome/widgets/welcome_appearance_page.dart`
- Modify: `lib/home/home.gui.dart`
- Modify: `lib/traduzioni/app_en.arb`
- Modify: `lib/traduzioni/app_it.arb`

**Interfaces:**
- Consumes: `IntroductionScreen`, `LocaleSettings.impostaLingua(Locale?)`, `ThemeSettings.setThemeMode`, `setPrimaryColor`, `setBackgroundFollowsTheme`.
- Produces:
  - `class WelcomeScreen extends StatefulWidget`
  - `const WelcomeScreen({super.key})`
  - `class WelcomeLogic`
  - `Future<void> completeOverview()`
  - `WelcomeLanguagePage` and `WelcomeAppearancePage` custom page widgets.
  - `HomeScreen({super.key, this.startGuidedLogin = false})`, with `final bool startGuidedLogin` stored but consumed by Task 7.

- [ ] Add localized copy for Welcome, Language, Appearance, Skip, Back, Next, and Start, including semantic labels.
- [ ] Implement four introduction pages: purpose, interactive-guide explanation/privacy, language, and appearance.
- [ ] Make language choices system/English/Italian and call the existing `LocaleSettings` API immediately.
- [ ] Make appearance choices primary color, ThemeMode, and decorative-background behavior; every field is optional and reflects current `ThemeSettings` state.
- [ ] Keep Next enabled without changes and support Back to language and appearance.
- [ ] Add the optional `startGuidedLogin` field to `HomeScreen`; keep its default false so all existing constructors remain valid.
- [ ] On Done or Skip, mark only `WelcomeTourId.overview` complete and replace the route with `HomeScreen`, passing a one-shot request for guided login.
- [ ] Run `flutter gen-l10n` and `dart run lib/traduzioni/verifica_traduzioni.dart`.
  - Expected: all keys present in both languages.
- [ ] Run formatting and `flutter analyze`.
- [ ] Manually verify language changes re-render the current onboarding page and theme changes apply immediately in light and dark modes at phone and desktop widths.

### Task 5: Add the first-run gate

**Files:**
- Create: `lib/welcome/welcome_gate.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `WelcomePreferences.isCompleted(WelcomeTourId.overview)`, `WelcomeScreen`, `HomeScreen`.
- Produces:
  - `class WelcomeGate extends StatefulWidget`
  - `const WelcomeGate({super.key})`
  - a neutral loading scaffold while the overview state resolves.

- [ ] Implement `WelcomeGate` with one asynchronous preference read in `initState`; guard every asynchronous `setState` with `mounted`.
- [ ] On read failure, show `WelcomeScreen` rather than silently bypassing onboarding.
- [ ] Replace `home: const HomeScreen()` with `home: const WelcomeGate()` in `main.dart`.
- [ ] Run formatting and `flutter analyze`.
- [ ] Launch with a fresh app-data directory and verify Home never flashes before Welcome.
- [ ] Launch with overview completion set and verify Home opens directly.

### Task 6: Add shared tour presentation and Help action

**Files:**
- Create: `lib/welcome/widgets/welcome_help_button.dart`
- Create: `lib/welcome/widgets/welcome_tooltip.dart`
- Create: `lib/welcome/welcome_showcase_scope.dart`
- Modify: `lib/traduzioni/app_en.arb`
- Modify: `lib/traduzioni/app_it.arb`

**Interfaces:**
- Consumes: `WelcomeTourController`, `ShowcaseView.register`, named scopes, module-owned `GlobalKey` lists.
- Produces:
  - `class WelcomeHelpButton extends StatelessWidget`
  - `WelcomeHelpButton({required WelcomeTourId tourId, required VoidCallback onStart})`
  - `class WelcomeTooltip extends StatelessWidget`
  - `class WelcomeShowcaseScope extends StatefulWidget`
  - `WelcomeShowcaseScope({required String scopeName, required Widget child, bool enableAutoScroll = true})`

- [ ] Implement consistent localized tooltip presentation, Skip, Back, and Next affordances, and semantic labels.
- [ ] Implement named scope registration/unregistration in `WelcomeShowcaseScope`; registration must occur before any sequence starts.
- [ ] Ensure Escape dismisses with `WelcomeTourEndReason.dismissed` and does not persist completion.
- [ ] Ensure a route disposal dismisses its scope and removes any interaction barrier.
- [ ] Run localization generation, translation verification, formatting, and analysis.
- [ ] Manually resize and dismiss a temporary one-target showcase; verify target geometry refreshes and keyboard Escape restores interaction.

### Task 7: Integrate the real login tour and initial handoff

**Files:**
- Create: `lib/welcome/login/login_tour.dart`
- Modify: `lib/login/gui/login.gui.dart`
- Modify: `lib/home/home.gui.dart`
- Modify: `lib/traduzioni/app_en.arb`
- Modify: `lib/traduzioni/app_it.arb`

**Interfaces:**
- Consumes: `WelcomeShowcaseScope`, `WelcomeTourController`, `LoginPage.onLoginSuccess`, existing login actions.
- Produces:
  - `class LoginTourTargets` containing keys for URL, local-development choice, method, credentials region, submit, and connection result.
  - `List<GlobalKey> LoginTourTargets.sequenceFor(LoginMethod method)`
  - `LoginPage({super.key, this.onLoginSuccess, this.startWelcomeTour = false})`
  - Home one-shot initial-login request consumed exactly once.

- [ ] Wrap only real login controls with showcase targets; target callbacks must invoke the same methods as the real controls.
- [ ] Build a method-specific sequence so hidden credential fields are never targeted.
- [ ] Start after the first frame only when `startWelcomeTour` is true or automatic state permits it.
- [ ] Keep failed login active and retryable; do not complete on exceptions or validation errors.
- [ ] On successful login, end login as finished, close the route/dialog, notify Home, and schedule Home tour once.
- [ ] On close without Skip or success, dismiss without completion.
- [ ] Run localization, formatting, analysis, Linux debug build, and Android debug build.
- [ ] Manually exercise smartphone full-screen and desktop dialog login: failed, closed, skipped, and successful. Confirm only skip/success persist completion and success starts Home once.

### Task 8: Integrate Home and central guide management

**Files:**
- Create: `lib/welcome/home/home_tour.dart`
- Create: `lib/welcome/settings/guides_settings.gui.dart`
- Modify: `lib/home/home.gui.dart`
- Modify: `lib/settings/settings.gui.dart`
- Modify: `lib/traduzioni/app_en.arb`
- Modify: `lib/traduzioni/app_it.arb`
- Modify: `lib/doc/architecture.md`
- Modify: `lib/doc/architettura.md`
- Modify: `lib/doc/modules-map.md`
- Modify: `lib/doc/mappa-moduli.md`
- Modify: `lib/doc/user-guide.md`
- Modify: `lib/doc/guida-utente.md`
- Modify: `lib/doc/operational-flows.md`
- Modify: `lib/doc/flussi-operativi.md`

**Interfaces:**
- Consumes: all foundation interfaces from Tasks 2-7.
- Produces:
  - `class HomeTourTargets` for account status, module navigation, section opening, compact/desktop navigation, settings, and Help.
  - `class GuidesSettingsTab extends StatefulWidget`
  - a ninth Settings tab named Guides.
  - callbacks to replay one guide or reset guide completion.

- [ ] Add a Home Help action and breakpoint-aware target sequence; omit drawer-only or docking-only targets when absent.
- [ ] Consume the post-login Home request once after rendering and mark completion only on finish/skip.
- [ ] Add the Guides settings tab and increase `DefaultTabController.length` from 8 to 9.
- [ ] List only supported guide IDs, show completion state, permit one-guide launch, one-guide reset, and reset-all with confirmation.
- [ ] Make Home listen for `requestManualStart`, map each supported `WelcomeTourId` to its existing section ID/callback, consume the request once, and open only that destination and tour.
- [ ] Route requested login through `_showLoginModal`; route requested Home by focusing the existing Home view; use existing authentication and MGWS guards for module requests.
- [ ] If a requested destination cannot open because authentication or MGWS is unavailable, show the existing notice, leave completion unchanged, and never start a fallback tour.
- [ ] Document only the now-working first-run, login, Home, Help, and Guides behavior.
- [ ] Run localization generation, translation verification, formatting, analysis, Linux build, and Android build.
- [ ] Acceptance: replay Home after completion and confirm login/product/etc. state is unchanged; reset-all and confirm overview appears on the next cold start.

## Phase 2 — Catalog Tours

### Task 9: Product management tour

**Files:**
- Create: `lib/welcome/product_management/product_management_tour.dart`
- Modify: `lib/prodotti/prodotti_gestisci/prodotti_gestisci.gui.dart`
- Modify: `lib/prodotti/prodotti_gestisci/prodotti_gestisci_view.gui.dart`
- Modify: `lib/prodotti/prodotti_gestisci/prodotti_gestisci.code.dart` only if a private UI callback must be exposed without moving business logic.
- Modify: translation ARB files and user-guide/module-map pairs.

**Interfaces:**
- Consumes: foundation Help/scope/controller interfaces.
- Produces: `ProductManagementTourTargets`, state-aware sequence for filters, search mode, active filters, columns, selection, detail, pagination, quick edit, and informational sensitive actions.

- [ ] Map each target to an existing real control and extract only reusable UI callbacks needed by target taps.
- [ ] Filter detail/selection/quick-edit targets until a product or selection exists; use tooltip Next where performing mutation is unsafe.
- [ ] Add automatic first-open and current-screen manual Help behavior.
- [ ] Add localized copy and current documentation.
- [ ] Run standard localization, format, analyze, Linux-build, and Android-build checks.
- [ ] Acceptance at narrow and wide widths: hidden columns and desktop detail targets are skipped without errors; manual replay changes no other completion state.

### Task 10: Product creation and editing tour

**Files:**
- Create: `lib/welcome/product_creation/product_creation_tour.dart`
- Modify: `lib/prodotti/prodotti_crea/prodotti_crea.gui.dart`
- Modify: `lib/prodotti/prodotti_crea/prodotti_crea.code.dart` only for shared UI callbacks.
- Modify: relevant translation and documentation files.

**Interfaces:**
- Produces: `ProductCreationTourTargets` with sequences branching by create/edit mode and simple/variable product type.

- [ ] Target real product type, base fields, taxonomy/status, images, MGWS inventory, attributes/variants, barcode, recap, and save.
- [ ] Require safe navigation interactions; explain Save without invoking it.
- [ ] Recompute the sequence when product type changes so hidden simple/variable fields are never targeted.
- [ ] Add automatic/manual activation, localization, and documentation.
- [ ] Run standard checks and accept create/edit plus simple/variable branches at phone and desktop widths.

## Phase 3 — Stock and Point of Sale Tours

### Task 11: MGWS inventory tour

**Files:**
- Create: `lib/welcome/inventory/inventory_tour.dart`
- Modify: `lib/inventory/inventory.gui.dart`
- Modify: `lib/inventory/inventory.code.dart` only for shared callbacks.
- Modify: relevant `inventory_*.gui.dart` files only where their real target widgets live.
- Modify: translation and documentation files.

**Interfaces:**
- Produces: `InventoryTourTargets` and mode-specific sequences for Add, Reconcile, Move, and Movements.

- [ ] Target selector, details, product picker, quick mode, quantities/locations, reason, preview, and ledger using only mounted controls.
- [ ] Explain submissions, movement edits, and reversals without execution.
- [ ] When MGWS is unavailable, show the existing availability explanation and omit unavailable operational targets.
- [ ] Add automatic/manual activation, localization, documentation, and standard checks.
- [ ] Acceptance: each inventory mode, empty/product-selected state, and MGWS unavailable state completes or exits without target lookup failure.

### Task 12: Cashier tour with optional shift branch

**Files:**
- Create: `lib/welcome/cashier/cashier_tour.dart`
- Modify: `lib/cassa/cassa.gui.dart`
- Modify: `lib/cassa/cassa.code.dart` only for shared callbacks.
- Modify: `lib/settings/cassa_settings.gui.dart`
- Modify: relevant translation and documentation files.

**Interfaces:**
- Produces: `CashierTourTargets`, `CashierTourCheckpoint`, and optional cross-screen shift-configuration branch.

- [ ] Target barcode input without guiding the shared scanner, manual add, basket controls, customer/loyalty/coupon/suspension, total, receipt history, and returns.
- [ ] Explain payment, sale, and return submission without invoking them.
- [ ] Explain that shifts are optional and offer `Configure shifts` or `Continue without shifts`.
- [ ] For Configure, checkpoint the cashier tour, navigate to the real cashier settings, let the user decide whether to change it, and return/resume safely.
- [ ] Include Open/Close shift targets only when the setting makes them visible; do not activate the setting automatically.
- [ ] Add automatic/manual activation, localization, documentation, and standard checks.
- [ ] Acceptance: shifts disabled-and-skipped, enabled, configured then unchanged, configured then enabled, Back, and route-close branches.

## Phase 4 — Commerce and People Tours

### Task 13: Orders tour

**Files:**
- Create: `lib/welcome/orders/orders_tour.dart`
- Modify: `lib/ordini/ordini_gestisci/ordini_gestisci.gui.dart`
- Modify: `lib/ordini/ordini_gestisci/ordini_gestisci.code.dart` only for shared callbacks.
- Modify: translation and documentation files.

- [ ] Guide search, filters, order selection, detail, and status controls; keep state-changing operations informational.
- [ ] Filter detail targets when no order is selected.
- [ ] Add automatic/manual activation and standard checks; accept empty and populated order lists.

### Task 14: Customers tour

**Files:**
- Create: `lib/welcome/customers/customers_tour.dart`
- Modify: `lib/clienti/clienti_gestisci.gui.dart`
- Modify: `lib/clienti/clienti_gestisci.code.dart` only for shared callbacks.
- Modify: translation and documentation files.

- [ ] Guide search, list, details, create, and edit; explain save without requiring it.
- [ ] Add state-aware targets, automatic/manual activation, localization, documentation, and standard checks.

### Task 15: Suppliers tour

**Files:**
- Create: `lib/welcome/suppliers/suppliers_tour.dart`
- Modify: `lib/inventory/inventory_suppliers.gui.dart`
- Modify: `lib/inventory/inventory_suppliers.code.dart` only for shared callbacks.
- Modify: purchase-order/reorder/receipt GUI files only for actual target widgets.
- Modify: translation and documentation files.

- [ ] Guide search/list, supplier detail, reorder, purchase orders, and reception.
- [ ] Keep consequential MGWS submissions informational and handle MGWS unavailable with existing behavior.
- [ ] Add automatic/manual activation and standard checks.

### Task 16: Loyalty tour

**Files:**
- Create: `lib/welcome/loyalty/loyalty_tour.dart`
- Modify: `lib/carta_fedelta/carta_fedelta.gui.dart`
- Modify: `lib/carta_fedelta/carta_fedelta.code.dart` only for shared callbacks.
- Modify: translation and documentation files.

- [ ] Guide customer/card lookup, balance, and history; keep point changes informational.
- [ ] Add MGWS-aware target filtering, automatic/manual activation, and standard checks.

### Task 17: Coupons tour

**Files:**
- Create: `lib/welcome/coupons/coupons_tour.dart`
- Modify: `lib/coupon/coupon_gestisci/coupon_gestisci.gui.dart`
- Modify: `lib/coupon/coupon_gestisci/coupon_gestisci_view.gui.dart`
- Modify: `lib/coupon/coupon_gestisci/coupon_gestisci.code.dart` only for shared callbacks.
- Modify: translation and documentation files.

- [ ] Guide search/list, details and conditions, create/edit; keep save/delete informational.
- [ ] Add state-aware targets, automatic/manual activation, and standard checks.

### Task 18: Employees tour

**Files:**
- Create: `lib/welcome/employees/employees_tour.dart`
- Modify: `lib/dipendenti/dipendenti.gui.dart`
- Modify: `lib/dipendenti/dipendenti.code.dart` only for shared callbacks.
- Modify: translation and documentation files.

- [ ] Guide list/search, detail, WordPress association, roles/capabilities, and active credentials.
- [ ] Omit permission targets for unlinked employees and explain revocation/permission changes without invoking them.
- [ ] Add capability/MGWS-aware filtering, automatic/manual activation, and standard checks.

## Phase 5 — Analysis, Settings, and Completion

### Task 19: Reports tour

**Files:**
- Create: `lib/welcome/reports/reports_tour.dart`
- Modify: `lib/report/report.gui.dart`
- Modify: `lib/report/report.code.dart` only for shared callbacks.
- Modify: translation and documentation files.

- [ ] Guide template selection, configuration, preview, print, and export.
- [ ] Permit real file-producing actions only through their normal confirmation behavior.
- [ ] Add state-aware targets, automatic/manual activation, and standard checks.

### Task 20: Dashboard tour

**Files:**
- Create: `lib/welcome/dashboard/dashboard_tour.dart`
- Modify: `lib/dashboard/dashboard.gui.dart`
- Modify: `lib/dashboard/dashboard.code.dart` only for shared callbacks.
- Modify: `lib/dashboard/dashboard_report_panel.gui.dart`
- Modify: translation and documentation files.

- [ ] Guide period, primary metrics, charts/details, analysis panel, and PDF/CSV generation.
- [ ] Filter targets while dashboard data is loading or unavailable.
- [ ] Add automatic/manual activation and standard checks across phone/tablet/desktop layouts.

### Task 21: General settings tour

**Files:**
- Create: `lib/welcome/settings/settings_tour.dart`
- Modify: `lib/settings/settings.gui.dart`
- Modify: general, theme, product-image, inventory, cashier, shortcut, and WordPress-backend settings GUI files only for actual supported target widgets.
- Modify: translation and documentation files.

- [ ] Guide language, location, theme, images, inventory, cashier, shortcuts, WordPress backend, and Guides.
- [ ] Explicitly exclude AI and RFID tabs and never target them.
- [ ] Treat settings as optional: offer navigation and explanation without requiring a value change.
- [ ] Add tab-aware checkpoints, automatic/manual activation, and standard checks.

### Task 22: Complete current documentation and localization audit

**Files:**
- Modify: all documentation pairs listed in the spec.
- Modify: `lib/traduzioni/app_en.arb`
- Modify: `lib/traduzioni/app_it.arb`

**Interfaces:**
- Consumes: completed Tasks 1-21.
- Produces: documentation matching only shipped behavior and complete bilingual welcome keys.

- [ ] Remove wording that describes unimplemented or excluded guides.
- [ ] Document first run, guide replay, reset, local-only persistence, conditional optional features, and safety behavior.
- [ ] Search Dart sources for visible welcome strings not using `context.l10n` and replace them.
- [ ] Run `flutter gen-l10n` and `dart run lib/traduzioni/verifica_traduzioni.dart`.
  - Expected: all translation checks pass.
- [ ] Run `flutter analyze`.
  - Expected: no issues.

### Task 23: Full-system acceptance and release readiness

**Files:**
- Modify only files required to fix failures found by this task.
- Update `todo.md` only for unresolved risks or follow-ups that remain after verification.

**Interfaces:**
- Consumes: the entire implementation.
- Produces: verified welcome and guided-tour feature ready for user review.

- [ ] Run `dart format --output=none --set-exit-if-changed lib/welcome lib/main.dart` plus every modified integration file.
- [ ] Run `flutter gen-l10n`.
- [ ] Run `dart run lib/traduzioni/verifica_traduzioni.dart`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter build linux --release`.
- [ ] Run `flutter build apk --release`.
- [ ] Verify a clean first run: Welcome → Language → Appearance → Login → Home.
- [ ] Verify overview Skip, login failure, login dismissal, login success, and Home one-shot behavior.
- [ ] Verify every supported module starts only its own tour on first opening and manual replay starts only that module.
- [ ] Verify every excluded area has no automatic tour, target, Help entry, or guide-settings entry.
- [ ] Verify reset-one and reset-all behavior after a cold restart.
- [ ] Verify role-, breakpoint-, entity-, optional-setting-, and MGWS-dependent target filtering.
- [ ] Verify active-overlay navigation, window resize/orientation, Escape, logout, and route disposal restore normal interaction.
- [ ] Verify light, dark, system theme, custom primary color, decorative backgrounds, Italian, English, and system locale.
- [ ] Review `git diff` to ensure no generated build artifacts, credentials, screenshots, or unrelated refactors are included.
- [ ] Record unresolved non-blocking items in `todo.md`; report blocking failures instead of declaring completion.
