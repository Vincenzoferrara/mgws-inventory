# Architecture

## Layers

- Flutter UI
- Screen logic
- Domain services
- Backend connectors

## Folder structure

- Each main page or module lives in a dedicated folder under `lib/`.
- UI and screen logic are split into sibling files when the module is large enough:
  - `module_name.gui.dart` for widgets, layout and user interaction
  - `module_name.code.dart` for state, orchestration and screen logic
- `lib/reuse_class/` contains reusable components and shared utilities.
- `lib/reuse_class/barcode/` centralizes barcode scanning and internal barcode generation.
- `lib/reuse_class/datagridview/` contains the shared table grid used by operational tables.
- `lib/reuse_class/device_utils/` classifies smartphone, tablet and desktop layouts.
- `login/jwt_api/` is the integration layer for WordPress, WooCommerce and MGWS connectors.
- `login/mgws/connection/` owns the MGWS connection state and the service availability check.
- `login/mgws/query/` contains the MGWS API clients.
- `settings/` contains app settings and module settings views.

## Settings architecture

`settings.gui.dart` is the settings container. Module-specific settings must have their own view and must not be mixed into unrelated global settings. `AppSettings` should contain only truly global settings or settings used by global classes.

## Main nodes

- `main.dart` starts the app, theme, localization and runtime services.
- `home/` controls navigation and desktop docking.
- `login/` manages authentication and authenticated connectors.
- `settings/` stores global preferences and module settings views.
- `inventory/` manages MGWS stock operations and movement ledger UI.
- `cassa/` delegates POS checkout to MGWS and keeps local POS receipt history.
- `dashboard/` loads and exports analytical data.

## MGWS contract

- `login/mgws/query/` contains the MGWS clients used by the app.
- `login/mgws/connection/mgws_connection.dart` is the single owner of the MGWS connection state. No module keeps its own copy.
- `MgwsConnection.ensureConnected()` is the entry point for modules: it reuses the verification already produced by the login chain and hits the network only when the state is unknown.
- `MgwsConnection.verify()` is reserved for explicit actions: the end of the login chain and deliberate user-triggered checks. Modules must not call it.
- `MgwsConnection.markDisconnected()` invalidates the state on every session change, so a stale state never blocks a module.
- `MgwsUnavailableReason` keeps the failure cause so the notice can tell a non-reachable backend, a disabled service and a missing session apart.
- `login/mgws/connection/` does not import `login/mgws/query/`: availability must not depend on a specific client.
- `WooConnect` owns authenticated transport and site URL state.
- MGWS clients must not create separate connectors.
- `QueryMgwsPos` handles idempotent POS checkout.
- The receipt number is allocated by MGWS during checkout, not by the app. `mg_pos_receipts` holds one row per POS document, and the unique index on `(business_day_id, register_name, sequential_number)` makes a duplicate number impossible at database level, so two tills cannot produce the same receipt number and a reinstall cannot restart the sequence.
- Each register keeps an independent sequence per business day, so the daily total for a till is `COUNT(*)` grouped by register. `business_day_id` is also the shift's operating day and stays distinct from the receipt number.
- With a fiscal register attached the device issues the number and the app sends it as `receipt_number`; the server records it instead of allocating it.
- The checkout response carries `sequential_number`. When it is missing, the app falls back to a local counter that resumes from the local maximum, so a sale is never lost and the sequence never goes backwards.
- `cassa/fiscal_register/` isolates the fiscal register behind a driver contract. The POS never speaks a vendor protocol: every manufacturer exposes its own API, so there is no universal driver.
- `FiscalRegisterRepository` selects the active driver and persists the choice. Simulation mode is a declared way of working, not a fallback: it is what runs when no register is attached.
- The checkout asks the driver to issue the receipt. In simulation the driver issues nothing and returns no number, so the POS keeps its own receipt sequence. `Scontrino.numeroProgressivoDispositivo` holds the number when a device issues one.
- A failing driver never blocks the till: the sale is recorded and the failure is logged, because losing the receipt is worse than an unissued document.
- Pairing the till with a register is not an app feature. It is a one-off registration the merchant performs in the "Fatture e Corrispettivi" portal, and the app only exposes the POS identifier it needs for that.
- `QueryMgwsInventory` handles stock reads, stock writes, movement ledger, suppliers, reordering, purchase orders, receptions and counts.
- `QueryMgwsLoyalty` handles loyalty service status, customer lookup, cards, points and history.
- Employee roles/capabilities are managed only for MGWS employees linked to a WordPress user.

## Login and security

Login is the most sensitive part of the app. Every change to login must be reviewed for security risk. No insecure fallback or temporary credential shortcut is allowed.

## Login and MGWS chain

The login chain verifies MGWS at its end, following the same path for every credential type: JWT, WordPress Basic Auth, WooCommerce consumer keys and auto-connect.

1. Every connection method starts with `MgwsConnection.markDisconnected()`, so the previous site state cannot survive a session change.
2. When the session succeeds, `MgwsConnection.verify()` reads the MGWS service status routes. When the session fails, MGWS is not contacted and the login stops.
3. A failed MGWS verification does not fail the login: WooCommerce sections stay usable and the modules that need MGWS report the backend as unavailable.

A section that needs MGWS declares `requiresMgws` and is not opened without a working backend. `Cashier` and `Suppliers` are MGWS-only: cashier shifts and checkout are confirmed by the MGWS server, and the supplier registry exists only in MGWS routes.

## Privacy and de-Googled design

The app must remain privacy-first. Google services must not be a base architectural dependency. If a feature can work without Google, it must be able to work without Google. Hidden tracking, telemetry, ads and unnecessary data collection are not allowed.

## Principles

- UI and backend remain separated.
- Dependencies on external WordPress plugins pass through MGWS.
- WooCommerce remains the e-commerce engine.
- MGWS manages custom operational logic and POS.
- The Flutter app talks directly only with WooCommerce and MGWS inside the WordPress perimeter.
- Persistent shared data must pass through WordPress/MGWS.
- Temporary UI state stays in Flutter.
