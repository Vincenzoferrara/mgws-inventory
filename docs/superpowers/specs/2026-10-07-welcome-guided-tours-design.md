# Welcome and Guided Tours Design

## Objective

Add a first-run welcome flow and contextual guided tours that teach users how to operate the real application interface. The system must work on smartphone, tablet, and desktop layouts, remain fully localized, and keep completion state locally on the device.

The guided tours must highlight and operate real controls. They must not use screenshots, simulated screens, or demo data. Safe controls can be clicked during a tour. Destructive, commercial, or otherwise consequential operations are explained without requiring execution.

## Scope

The feature covers:

- first-run welcome;
- language selection;
- appearance configuration;
- guided login;
- guided home navigation;
- contextual tours for the supported operational modules;
- manual replay of the current screen's tour;
- a central guide-management section in settings;
- local persistence of completion state.

The following areas are explicitly excluded:

- CalDAV;
- log viewer;
- shared barcode and QR scanner;
- RFID settings and workflows;
- AI settings and workflows;
- updater and application update screen.

## Dependencies

### Introduction Screen

Use `introduction_screen 5.0.1` only for the initial welcome, language, and appearance pages. The application requires Flutter `>=3.44.0`; local development and CI currently use Flutter `3.47.5`.

### ShowcaseView

Use `showcaseview 5.1.0` for overlays on real interface controls. It supports scoped tours, custom tooltips, target callbacks, automatic scrolling, and explicit lifecycle handling.

### Local persistence

Use the existing `shared_preferences` dependency. Tour state must not depend on authentication, WooCommerce, or MGWS and must not be synchronized between devices.

## First-run sequence

The initial flow is:

1. Welcome.
2. Language.
3. Appearance.
4. Guided real login.
5. Guided real home.
6. Normal application use.
7. A module-specific tour when each supported module is first opened.

### Welcome

The welcome page explains the application's purpose, how interactive guides behave, and that guide completion state is stored locally. It contains no screenshots or simulated application controls.

### Language

The language page appears before appearance and login so subsequent content immediately uses the selected locale. It offers:

- system language;
- Italian;
- English.

The selection uses the existing `LocaleSettings` state and applies immediately. Keeping the system language is valid, and the user can always continue without making a change.

### Appearance

The appearance page uses the same state and behavior as the existing theme settings. It offers:

- primary color;
- light, dark, or system theme mode;
- decorative background settings.

Changes appear immediately. Every choice is optional, and `Next` remains available without modification. `Back` allows returning to language and appearance choices.

### Guided login

After the initial pages, the application opens the real login interface and guides the user through:

- site URL;
- local-development option;
- authentication method;
- credentials for the selected method;
- real login action;
- connection result.

The login action is safe and can be required. A failed login keeps the user in the login flow and permits retry. Closing login without authenticating does not mark the login tour complete unless the user explicitly skips it.

### Guided home

After successful authentication, the application returns to the real home and guides the user through:

- authenticated-user status;
- module cards or menu;
- opening a section;
- desktop tabs or compact navigation;
- settings and guide access.

## Architecture

Use independent module tours coordinated by a central controller. Do not create one global sequence containing every module, and do not use a dynamic global target registry.

The proposed structure is:

```text
lib/welcome/
├── welcome.gui.dart
├── welcome.code.dart
├── welcome_gate.dart
├── welcome_preferences.dart
├── welcome_tour_controller.dart
├── welcome_tour_ids.dart
├── widgets/
│   ├── welcome_help_button.dart
│   └── welcome_tooltip.dart
├── login/
│   ├── login_welcome_page.dart
│   └── login_tour.dart
├── home/
│   ├── home_welcome_page.dart
│   └── home_tour.dart
├── product_management/
├── product_creation/
├── inventory/
├── cashier/
├── orders/
├── customers/
├── suppliers/
├── loyalty/
├── coupons/
├── reports/
├── dashboard/
├── employees/
└── settings/
```

Each module folder contains its tour definition and any welcome-specific widgets needed by that module. Application business logic remains in the existing module. Tour code may call public screen callbacks but must not own product, order, stock, payment, authentication, or backend logic.

## Application entry gate

`main.dart` continues to initialize theme and locale before `runApp`. The `MaterialApp` home becomes a `WelcomeGate` that resolves local completion state before choosing between the welcome flow and `HomeScreen`.

The gate must display a neutral loading state while reading preferences so the home does not flash before the welcome flow.

## Tour registration and lifecycle

Every guided screen:

- registers its own named `ShowcaseView` scope;
- owns `GlobalKey` instances only for controls on that screen;
- requests automatic start after the first frame when appropriate;
- filters unavailable targets before starting;
- dismisses active overlays and unregisters its scope on disposal;
- exposes a manual Help action that starts only that screen's tour.

Only one tour can be active at a time. Logout, session replacement, and route disposal dismiss the active overlay without clearing completion preferences.

## Real-control interaction

The feature does not create screenshots, replicas, or demonstrations. A tour target identifies a real control in the mounted screen.

To avoid duplicated behavior, the real control and the tour target callback invoke the same application callback:

```text
Real control ────────┐
                     ├── shared application callback
Tour target action ──┘
```

Actions fall into four categories:

1. **Safe interaction**: the user clicks the real action to continue.
2. **Navigation interaction**: the current overlay closes, the real destination opens, and the tour resumes after rendering.
3. **Sensitive interaction**: the control is explained, but a tour `Next` action advances without invoking it.
4. **Informational target**: an interface region is described without interaction.

Sensitive interactions include sales, returns, payment, deleting data, submitting orders, changing stock, revoking credentials, applying loyalty points, and other actions with material effects.

## Optional functionality and branching

A tour must never enable optional application behavior automatically. It explains the option and adapts to the current configuration.

For example, cashier shift management is optional:

1. The cashier tour explains that shift opening and closing depend on the cashier setting.
2. The user can choose `Configure shifts` or `Continue without shifts`.
3. `Configure shifts` navigates to the real cashier settings.
4. The user decides whether to change the setting.
5. If shifts are enabled, the tour includes the real `Open shift` and `Close shift` controls.
6. If shifts remain disabled, those targets are omitted.

The same conditional pattern applies to every optional feature. Leaving an option disabled is valid and must not be treated as an error or incomplete setup.

## Cross-screen navigation

Showcase scopes are screen-specific. A cross-screen tour:

1. stores its logical checkpoint in `WelcomeTourController`;
2. dismisses the current overlay;
3. invokes the application's real navigation callback;
4. waits until the destination has rendered;
5. registers or resolves the destination scope;
6. resumes from the saved checkpoint.

The controller supports forward and backward movement where the underlying screen flow allows it. It must not attempt to keep an overlay alive across disposed routes.

## Persistence model

Use versioned, module-specific keys, including:

```text
welcome.v1.overview.completed
welcome.v1.login.completed
welcome.v1.home.completed
welcome.v1.productManagement.completed
welcome.v1.productCreation.completed
welcome.v1.inventory.completed
welcome.v1.cashier.completed
welcome.v1.orders.completed
welcome.v1.customers.completed
welcome.v1.suppliers.completed
welcome.v1.loyalty.completed
welcome.v1.coupons.completed
welcome.v1.reports.completed
welcome.v1.dashboard.completed
welcome.v1.employees.completed
welcome.v1.settings.completed
```

Completion behavior:

- finishing a tour marks only that tour complete;
- skipping a tour also marks only that tour complete;
- dismissing due to navigation, route disposal, logout, or an error does not mark it complete;
- manual replay does not clear or alter other modules;
- a future materially changed tour can use a new version prefix.

## Automatic and manual activation

### Automatic activation

- The overview starts only on first run.
- Login and home follow the approved first-run sequence.
- Each supported module starts its own tour only on its first opening.
- A completed or skipped module does not start automatically again.

### Manual activation

Every supported screen exposes a Help action. It replays only the current screen's tour, even if the overall onboarding has already been completed.

Settings contains a `Guides` section with:

- supported guide list;
- completed or not-completed state;
- action to start one specific guide;
- action to reset all local guide completion states.

Starting a guide from settings navigates explicitly to that guide. It does not start a chain through all modules.

## Module content

Final target availability and control names must be verified against the implementation before adding each tour.

### Product management

- filter panel;
- name, SKU, and barcode search modes;
- active filters and clear action;
- column chooser;
- row selection;
- product detail;
- pagination;
- quick edit;
- sensitive bulk and delete actions as informational steps.

### Product creation and editing

- required product type selection;
- base information;
- categories, tags, and publication status;
- images;
- MGWS inventory section;
- attributes and variants;
- barcode controls;
- recap;
- save action as an informational step.

### MGWS inventory

- Add, Reconcile, Move, and Movements selector;
- details field;
- existing-product selection;
- quick mode;
- quantity and location controls;
- required reason;
- operation preview;
- movement ledger;
- submissions, edits, and reversals as informational steps.

### Cashier

- barcode input, excluding the shared scanner tour;
- manual product addition;
- basket;
- quantity, discount, and removal;
- operation type;
- customer and loyalty card;
- coupon and suspension;
- total;
- payment as an informational step;
- receipt history and returns;
- conditional shift configuration and controls.

### Orders

- search and filters;
- order selection;
- details;
- status controls;
- modifying actions as informational steps.

### Customers

- search;
- customer list;
- details;
- create and edit;
- save as an informational step.

### Suppliers

- search and list;
- supplier details;
- reorder;
- purchase orders;
- reception;
- consequential MGWS operations as informational steps.

### Loyalty

- customer or card lookup;
- points balance;
- history;
- point changes as informational steps.

### Coupons

- search and list;
- conditions and details;
- create and edit;
- save and delete as informational steps.

### Reports

- template selection;
- configuration;
- preview;
- print and export with the application's normal confirmation behavior.

### Dashboard

- active period;
- primary metrics;
- charts and detail navigation;
- analysis panel;
- PDF and CSV generation.

### Employees

- list and search;
- employee details;
- WordPress user association;
- roles and capabilities;
- active credentials;
- revocation and permission changes as informational steps.

### Settings

Guide only general operational settings:

- language;
- location;
- theme;
- images;
- inventory;
- cashier;
- shortcuts;
- WordPress backend;
- Guides section.

Do not include AI or RFID settings.

## Localization

Every user-visible string must be read through `context.l10n`. Keys use English camelCase names prefixed with `welcome`, and values are added to both:

- `lib/traduzioni/app_en.arb`;
- `lib/traduzioni/app_it.arb`.

No tour title, tooltip, semantic label, error, button, or status text may be hardcoded in Dart.

## Accessibility and adaptive behavior

- Tooltips expose semantic labels.
- The active target is announced to assistive technologies.
- Skip, Back, Next, and Help remain keyboard accessible.
- Escape dismisses the current tour without completing it.
- Interactive areas meet Material minimum target sizing.
- Tooltip placement adapts above or below targets on small screens.
- Desktop placement remains inside the active window and does not cover the target.
- Off-screen targets use automatic scrolling when the screen supports it.
- Resizing and orientation changes trigger target geometry recalculation.
- Light, dark, system, and customized themes remain readable.

## Error handling

A target can be unavailable because of screen size, user capability, MGWS availability, selected entity type, configuration, or asynchronous rendering.

Before starting, each tour filters targets that are not valid for the current state. If a target disappears during execution, the controller skips it. If no valid targets remain, the tour exits without crashing and does not claim completion unless the user finished or skipped it.

Unavailable MGWS functionality is explained using the application's existing availability state. Tours must not initiate their own backend checks or bypass authentication and capability rules.

Technical details are written through the existing application logger and are not exposed directly in the UI.

## Verification strategy

Project policy prohibits creating tests unless explicitly requested, so this implementation does not add automated tests by default.

Each implementation block requires:

- Dart formatting;
- localization generation;
- translation consistency verification;
- static analysis;
- Linux build;
- Android build;
- manual checks at smartphone and desktop widths;
- first-run, finish, skip, and manual replay checks;
- successful, failed, and dismissed login checks;
- MGWS available and unavailable checks where applicable;
- light and dark theme checks;
- guide reset checks;
- conditional optional-feature branch checks.

## Documentation

Update current project documentation as behavior is implemented:

- `lib/doc/architecture.md` and `lib/doc/architettura.md`;
- `lib/doc/modules-map.md` and `lib/doc/mappa-moduli.md`;
- `lib/doc/user-guide.md` and `lib/doc/guida-utente.md`;
- `lib/doc/operational-flows.md` and `lib/doc/flussi-operativi.md`;
- configuration documentation where local guide preferences are described.

Documentation must describe only actual implemented behavior and must not present planned tours as available before their implementation.

## Implementation order

1. Add and verify `showcaseview 5.1.0`.
2. Add identifiers, local preferences, and the central controller.
3. Add `WelcomeGate`, welcome, language, and appearance.
4. Integrate guided login and guided home.
5. Add the shared Help action and tooltip presentation.
6. Add the central Guides settings section.
7. Integrate modules incrementally: product management, product creation, inventory, cashier, orders, customers, suppliers, loyalty, coupons, reports, dashboard, employees, and settings.
8. Complete localization and documentation for implemented behavior.
9. Run full supported-platform verification.
