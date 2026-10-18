# Developer Guide

## Before changing code

1. Read [Architecture](architecture.md).
2. Check the module documentation relevant to the change.
3. Preserve existing user work and unrelated working-tree changes.
4. Keep documentation in `lib/doc` aligned with current behavior.

## File organization

Large modules should split UI and logic:

- `*.gui.dart` for widgets, layout and user interaction
- `*.code.dart` for state, orchestration and screen logic

Reusable UI and domain utilities belong under `lib/reuse_class/`. Do not duplicate scanner, pagination, table or shared dialog behavior inside feature modules.

## Integration boundaries

The app may talk directly only to:

- WooCommerce
- MGWS

Do not add direct integrations to ATUM, myCred or other WordPress plugins. If a capability is needed, expose it through MGWS.

`WooConnect` is the owner of authenticated transport. MGWS clients must use its authenticated Dio and site URL instead of creating their own connector.

## Reading MGWS state in a module

`MgwsConnection` in `lib/login/mgws/connection/mgws_connection.dart` is the only owner of the MGWS connection state.

Rules:

- call `MgwsConnection.instance.ensureConnected()` before an MGWS operation; it reuses the verification already produced by the login chain and hits the network only when the state is unknown
- do not call `verify()` from a module. It is reserved for the end of the login chain and for deliberate user-triggered checks, because it always hits the network
- do not keep a module-local copy of the availability flag
- do not call `verify()` before every operation: permissions, supplier reads and stock reads do not need a fresh check and would multiply the requests
- a checkout or another action that must not run against a stale state uses `PlatformManager.refreshCanUseMgws()`
- call `markDisconnected()` when a session changes, so a stale state cannot block a module
- read `lastFailure` to tell a non-reachable backend, a disabled service and a missing session apart, and show the matching localized notice

A home section that cannot work without MGWS declares `requiresMgws: true` in its `_HomeSection`: the card is not opened and the notice is shown instead.

## Localization

Visible user strings must be localized through `context.l10n.<key>` and the ARB files under `lib/traduzioni/`.

Rules:

- template: `lib/traduzioni/app_en.arb`
- Italian translation: `lib/traduzioni/app_it.arb`
- keys are English, `camelCase`, and valid Dart getter names
- do not translate user data, protocol fields, persistence keys or backend payload names
- after touching visible strings run `flutter gen-l10n` and `dart run lib/traduzioni/verifica_traduzioni.dart`

## Documentation

`lib/doc` is current project documentation for contributors and AI agents. It is not a backlog and must not contain historical "before/after" notes. Update the most relevant file whenever behavior, settings, screens, integrations or user flows change.

## Testing and verification

Follow the verification relevant to the change. For documentation-only changes, run link checks and grep for stale references. For UI/string changes, also run localization checks. For Dart behavior changes, run `flutter analyze` and the relevant tests.

Do not add new tests unless the task explicitly asks for them; preserve existing tests and do not break them.

## SDK and dependency maintenance

Use Flutter with Dart `>=3.12.0 <4.0.0`. Dependency upgrades must keep the local `report_flutter` package at `../../report` resolvable together with the app.

`woocommerce_flutter_api` is kept on the latest compatible hosted release because WooCommerce is a direct integration boundary of the app. When upgrading packages, run `flutter pub upgrade --major-versions`, then `flutter pub get`, then `flutter analyze` from the app root. If dependency conflicts involve `report_flutter`, update that local package first and then rerun the app dependency resolution.

## Dashboard module (`lib/dashboard/`)

- `dashboard_customization.dart` is the page opened from Home: dashboard picker, filter bar, widget grid, edit mode with drag and drop, widget editor and visibility dialog.
- `dashboard_layout.dart` models dashboards, widgets and filters. `DashboardLayout.standard` holds one widget per `DashboardMetric` (an assert keeps it complete when a metric is added). The layout JSON uses lowercase snake_case keys because MGWS sanitizes keys with `sanitize_key`. A metric declares its shape (single value, time series, categories) and the chart types that fit it.
- `dashboard_widget_data.dart` turns `DashboardData`, the sales report, low-stock rows and category counts into a `DashboardDataset` (one value or labelled points). Charts only know these two shapes, so a new metric needs only a resolver branch and a label.
- `dashboard_widget_view.dart` draws a dataset as number, gauge, columns, bars, line, area, pie, donut or table. Parts of a whole use the fixed categorical palette; items past the seventh fold into "Other".
- `dashboard_layout_store.dart` stores dashboards through `QueryMgwsDashboards` (`GET /mgws/v1/dashboards`, `PUT`/`DELETE /mgws/v1/dashboards/{id}`). Personal dashboards live in the owner's user meta, shared ones (`everyone`, `admins`) in a site option; only `manage_options` or `manage_woocommerce` users can manage shared dashboards, and the server reports it as `can_manage_shared`. Without MGWS, personal dashboards fall back to `SharedPreferences`.
- Widgets load only the sources they need: the summary always, the sales report for product and category rankings, low-stock rows per threshold and category counts on demand.
- `DashboardMetric.report` widgets carry a `DashboardReportQuery` (measure, optional `ReportDimension`, `ReportFilterValue` list with the names shown in the editor). Their shape follows the split: none is a single value, a time split a series, any other split a ranking; use `DashboardWidgetConfig.shape`, `chartTypes` and `format`, not the metric's.
- `dashboard_report.dart` holds the measures offered (keys match the MGWS catalog), the presets (`ReportPreset`), `DashboardReportService` (MGWS calls, catalog values, product/customer/category/brand search) and the `DashboardReportRunner`/`DashboardReportSearch` typedefs the page accepts for offline tests. `dashboard_report_editor.dart` is the editor section and the filter picker.
- The page sends one MGWS request per distinct question (`dashboardReportKey`); the dashboard period, the comparison (single values only) and the widget order and limit are part of the request. Time splits come back with empty hours, days and months filled with zero.
- A new measure needs the MGWS engine (`includes/class-mgws-reports.php`), an entry in `reportMeasures`, a label in `reportMeasureLabel` and translations.

## Print module (`lib/report/`)

- Everything is stored by MGWS through `QueryMgwsPrint` (`login/mgws/query/query_mgws_print.dart`): `GET /print/library` returns templates, paper formats and categories with `can_manage` and `defaults_loaded`; `PUT`/`DELETE /print/{templates|paper-formats|categories}/{id}` change one item; `POST /print/defaults` loads the default library once per site. The item content travels as the `data_json` string because WordPress decodes JSON bodies into PHP arrays, where `{}` would become `[]`.
- `PrintLibrary` (`print_library.dart`, global `printLibrary`) holds the library. Every change goes to the server first; the local lists change only after the server accepted it. When the library is opened by a manager and `defaults_loaded` is false, it sends `PrintTemplateCatalog.defaultTemplates`, `PrintTemplateCatalog.defaultCategories` and `PaperFormatDefaults.all` in the manager's language.
- `PrintTemplate` holds kind, optional category, paper format id, colour/size separator and the `report_flutter` `ReportTemplate` design (one label, sign or report page, in millimetres). `PrintCategory` only orders the list (`position`). `PaperFormat` is data too, with `validationError` refusing cells outside the sheet. `PrintLibrary.paperFormatOf` falls back to another format of the same kind, or to a page the size of the design, when the stored format was deleted.
- `PrintSampleData.labelData` builds the fields of a label from a `PrintLabelItem` (product plus optional variant). Product keys reuse `ProdottoGlobal.toMap()` and add `taglia`, `colore`, `coloreTaglia`, `prezzoTesto`, `prezzoPrecedenteTesto`, `scontoTesto`; variant code, barcode and price replace the product ones. `coloreTaglia` is colour first, then size, joined by `PrintTemplate.variantSeparator`; `tagliaColore` carries the same value for templates saved with the older key. These keys are stored in saved templates: do not rename them. Colour and size come from the variant attributes through `trovaAttributo`, so `Color`/`Size` and `Colore`/`Taglia` both work. Report data is still example data.
- `print_job.dart`: `PrintJob.fromProducts` makes one line per variant (or simple product) with pieces in stock; each line prints exactly one label per piece (`PrintLabelItem.quantity` is the stock) and can only be removed (`PrintJob.without`); `PrintJob.merge` adds the lines chosen with `openProdottoPicker` (`Add label`) without duplicates; `pendingPrintJob` hands the job to the print section and `requestHomeSection(printSectionId)` (`home/home_section_requests.dart`) opens it. The product card prints the ticked variants only, through the same job. The products list calls `ProdottiGestioneController.productsWithVariants` first, so variable products without cached variants are downloaded.
- Deleting ticked variants from the product card (`ProdottiGestioneController.deleteVariants`) first reads each variant's MGWS stock (`getProductStock` with `variationId`) and rewrites it to 0 on every site with `reconcileStock` (`variationId`, one `movement_key` per deletion); the WooCommerce variation is deleted (`force: true`) only when zeroing succeeded, and nothing is deleted while MGWS is unavailable.
- `PrintPdfRenderer` draws the design elements with the designer units (positions, font sizes and strokes in mm), so print matches the designer canvas; `PrintRequest.skippedPerSheet` holds the positions already used at the start of each sheet and `PaperFormat.sheetSkips` turns it into one entry per printed sheet (used by both the renderer and the Print tab, so their sheet counts match; rolls never skip); text and table cells use `FittedBox(scaleDown)`, so the font size is a maximum and long text shrinks to its box; `PrintRequest.cellData` gives each label its own data. The `report_flutter` `PdfExporter` is not used because it mixes units and renders tables as placeholders. Images, logos, charts, formulas and markdown are not printed.
- PDFs embed Latin subsets of Noto Sans/Serif from `assets/fonts/` (SIL OFL, `assets/fonts/OFL.txt`): the standard PDF fonts have no euro sign.
- UI: `report.gui.dart` (`PrintCenterPage`, tabs and loading), `print_tab.gui.dart` (Print tab and `PrintCenterController` from `report.code.dart`), `template_tab.gui.dart` (Template tab), `paper_formats.gui.dart`, `print_designer.gui.dart` (`openPrintTemplateDesigner`, with paper format and separator bar), `print_preview.gui.dart` (raster preview of the same PDF that is printed) and `print_widgets.gui.dart` (grouped list and shared widgets).

## Android emulator and local backend

The project includes:

```bash
script/start_android_emulator.sh
```

It starts the configured local AVD and forwards host ports `8080` and `8081` to the emulator so local WordPress services are reachable from Android.

## Commits

Use the repository commit format:

```text
short title

- short detail
- short detail
```

Current project rules require commit messages in English.
