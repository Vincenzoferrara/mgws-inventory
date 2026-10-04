# mgws_inventory rebrand - design

Data: 2026-10-01

## Obiettivo

Rinominare l'app Flutter in **mgws_inventory**, rinominare il plugin WordPress in
**MGWS Inventory Wordpress Plugin**, togliere la scritta "INVENTO" dall'icona e allineare
tutti gli identificatori tecnici ai nuovi nomi.

## Decisioni prese

| Voce | Valore scelto |
| --- | --- |
| Nome visibile app | `mgws_inventory` |
| Package Dart | `mgws_inventory` -> `mgws_inventory` |
| ID Android | `it.mgws.mgws_inventory` |
| ID iOS/macOS/Linux | `it.mgws.mgws_inventory` |
| Nome visibile plugin | `MGWS Inventory Wordpress Plugin` |
| Slug cartella e text domain plugin | `mg-warehouse-stock` -> `mgws-inventory` |
| Repo GitHub app | `mgws_inventory` -> `mgws-inventory` |
| Repo GitHub plugin | `mg-warehouse-stock` -> `mgws-inventory-wordpress-plugin` |
| Icona | solo il simbolo, nessun testo |

Note sul naming: lo slug del plugin (`mgws-inventory`) e il nome del repo
(`mgws-inventory-wordpress-plugin`) sono due stringhe diverse. Lo slug e cio che WordPress
vede e da cui deriva il text domain, il repo e dove vive il codice. Non devono coincidere.

## 1. Nomi visibili dell'app

La stringa `mgws_inventory` sostituisce i nomi incoerenti oggi presenti: l'AppBar dice
"mgws_inventory", Windows e iOS dicono "mgws_inventory", il titolo
della pagina web dice "mgws_inventory".

### Traduzioni

In `lib/traduzioni/app_it.arb` e `app_en.arb`:

| Chiave | Nuovo valore |
| --- | --- |
| `appTitle` | `mgws_inventory` |
| `homeTitoloDesktop` | `mgws_inventory` |
| `homeTitoloMobileBack` | `mgws_inventory` |
| `homeTitoloDrawer` | `mgws_inventory` |
| `homeBenvenutoSottotitolo` | `mgws_inventory` |

`homeBenvenutoTitolo` resta "Benvenuto nel Sistema di Gestione" / "Welcome to the
Management System": e un testo localized, non il nome tecnico dell'app.

### Metadati di piattaforma

- `android/app/src/main/AndroidManifest.xml`: `android:label`
- `ios/Runner/Info.plist`: `CFBundleDisplayName`, `CFBundleName`
- `macos/Runner/Info.plist`: `CFBundleName`
- `windows/runner/Runner.rc`: `FileDescription`, `ProductName`
- `web/index.html`: `<title>`

## 2. Identificatori tecnici

### Package Dart

`pubspec.yaml`: `name: mgws_inventory`. Poi 15 file con import
`package:mgws_inventory/...`:

- `lib/login/gui/login.gui.dart`
- `lib/login/jwt_api/woo_connect.dart`
- `lib/log_viewer/log_viewer.gui.dart`
- `lib/prodotti/prodotti_crea/widgets/media_selector_dialog.dart`
- `test/inventory/inventory_flows_test.dart`
- `test/inventory/inventory_panels_test.dart`
- `test/prodotti/barcode_generator_test.dart`
- `test/prodotti/filters_bar_layout_test.dart`
- `test/prodotti/prodotto_filters_test.dart`
- `test/prodotti/product_visual_refresh_test.dart`
- `test/prodotti/variant_combinations_test.dart`
- `test/reuse_class/datagridview/datagridview_context_menu_test.dart`
- `test/reuse_class/datagridview/datagridview_min_width_test.dart`
- `test/reuse_class/datagridview/datagridview_pricing_test.dart`
- `test/support/product_visual_fixtures.dart`

### Android

- `android/app/build.gradle.kts`: `namespace` e `applicationId` -> `it.mgws.mgws_inventory`
- `MainActivity.kt` spostato in `android/app/src/main/kotlin/it/mgws/mgws_inventory/` con il
  `package` aggiornato
- `android/app/build.gradle.kts.backup`: file di backup, non va toccato

### iOS e macOS

Bundle id -> `it.mgws.mgws_inventory`:

- `ios/Runner.xcodeproj/project.pbxproj` (6 occorrenze)
- `macos/Runner.xcodeproj/project.pbxproj` (9 occorrenze)
- `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` (4 occorrenze)
- `macos/Runner/Configs/AppInfo.xcconfig`: `PRODUCT_NAME` -> `mgws_inventory`,
  `PRODUCT_BUNDLE_IDENTIFIER`

### Linux

- `linux/CMakeLists.txt`: `BINARY_NAME` -> `mgws_inventory`,
  `APPLICATION_ID` -> `it.mgws.mgws_inventory`
- `linux/runner/my_application.cc`

### Windows

- `windows/CMakeLists.txt`: nome progetto
- `windows/runner/main.cpp`
- `windows/runner/Runner.rc`: `OriginalFilename` -> `mgws_inventory.exe`

### Updater desktop

`lib/updater/updater_service.dart` (righe 28 e 34): le due URL del repository GitHub da cui
Velopack scarica le release passano a `mgws-inventory`. Il repo va rinominato su GitHub,
altrimenti l'updater automatico smette di funzionare.

Attenzione: il repository GitHub reale dell'app e `mgws-inventory`; le URL dell'updater devono usare il nome del repository, non il package Dart `mgws_inventory`.

### Cosa NON si tocca

`script/create_android_release_key.sh`: `KEY_ALIAS` e il nome del file keystore restano
`mgws_inventory`. Lo stesso alias e nel secret GitHub `ANDROID_KEY_ALIAS`, e
il keystore esistente contiene un alias con quel nome: rinominarlo romperebbe la firma delle
release. Non e visibile all'utente.

## 3. Logo e icone

La scritta "INVENTO" occupa `x 272-745`, `y 759-832` in un'immagine 1024x1024, ed e isolata:
sopra e sotto c'e solo gradiente. La rimozione e gia stata prototipata e verificata
ricostruendo il gradiente con una regressione lineare sulle righe di riferimento, con residuo
massimo 2/255 e nessuna banda visibile nemmeno al 200% di ingrandimento.

- Applicare il risultato a `icon/icon.png` e `icon/icon_trimmed.png`, che sono identici
- `icon/icon_trimmed.png` e la sorgente dichiarata in `pubspec.yaml`
  (`flutter_launcher_icons.image_path` e `adaptive_icon_foreground`), quindi da lì si
  rigenerano le icone con `dart run flutter_launcher_icons`
- `flutter_launcher_icons` copre `android: true` e `ios: true`, ma non macOS e Windows:
  rigenerare a mano `macos/Runner/Assets.xcassets/AppIcon.appiconset/` (7 file) e
  `windows/runner/resources/app_icon.ico`

## 4. Plugin WordPress

### Nome e intestazioni

- `Plugin Name` -> `MGWS Inventory Wordpress Plugin`
- `readme.txt`: titolo `=== MGWS Inventory Wordpress Plugin ===` e descrizione breve
  coerente
- `readme.txt`: le istruzioni di installazione che dicono di caricare la cartella
  `mg-warehouse-stock` vanno aggiornate a `mgws-inventory`

### Slug, file principale e text domain

- cartella `MG-Warehouse-Stock-plugin-wordpress` -> `mgws-inventory`
- file principale `mg-warehouse-stock.php` -> `mgws-inventory.php`: WordPress pretende che il
  file principale abbia il nome della cartella
- text domain `mg-warehouse-stock` -> `mgws-inventory` in 14 file di codice:
  `includes/mgws-db.php` (24 occorrenze), `includes/class-mgws-plugin.php` (162),
  `includes/class-mgws-rest-api.php` (10), `assets/admin-masterdata.js` (108),
  `assets/admin-product.js` (24), `assets/admin-order.js` (15), `bin/make-pot.php`,
  `bin/build-release.sh`, `readme.txt`, `mg-warehouse-stock.php`,
  `languages/mg-warehouse-stock.pot`, `tests/mgws_contract_test.php`,
  `tests/security_coverage_test.php`, `tests/uninstall_test.php`
- rigenerare `languages/mgws-inventory.pot` con `bin/make-pot.php` e rimuovere il vecchio
  `.pot`, che ha il nome dello slug vecchio

I tre documenti sotto `docs/superpowers/` che contengono il text domain
(`plans/2026-09-28-execution-ledger.md`, `plans/2026-09-28-wordpress-org-readiness.md`,
`specs/2026-09-28-wordpress-org-readiness-design.md`) **non si toccano**: registrano
decisioni prese a quel momento e riscriverli falsificherebbe la traccia.

### URL del repository

- `bin/make-pot.php`: `Report-Msgid-Bugs-To` -> repository `mgws-inventory-wordpress-plugin`
- `lib/doc/integrazioni.md` (app): URL del repository companion

### Docker

`docker/wordpress-docker/docker-compose.yml` monta la cartella del plugin in
`/var/www/html/wp-content/plugins/mg-warehouse-stock`. La destinazione diventa
`mgws-inventory`.

Per la regola 15 di `OPENCODE.md`, ogni modifica a `docker/` va in **un unico commit** dal
titolo `docker wordpress update`.

Il percorso assoluto oggi montato (`/home/vincenzo/Desktop/softwere/...`) non corrisponde a
dove vive il repo e contiene anche un errore di battitura. Il mount e gia rotto: qui si
cambia solo il nome della destinazione dentro il percorso, non il percorso assoluto, che e
una decisione separata.

## 5. Rischi

### L'app Android diventa un'app nuova

Cambiando `applicationId`, Android la considera un'app diversa. Chi ce l'ha deve
disinstallare la vecchia e installare la nuova, e perde i dati locali: storico scontri POS,
impostazioni, tema e lingua salvati. I dati lato server non si toccano.

### La migrazione del plugin richiede manualita

Chi ha il plugin installato deve disattivare il vecchio slug e attivare il nuovo.
`uninstall.php` elimina 18 tabelle, opzioni, tipi di contenuto, user meta e capability:
**la routine di disinstallazione non deve mai essere lanciata** o si perde tutto lo stock.
La strada sicura e sostituire i file e disattivare/attivare senza usare "Elimina".

In Docker il database conserva il vecchio slug in `wp_options.active_plugins`, quindi il
vecchio va disattivato prima di riavviare.

### Repo GitHub

Entrambi i repo vanno rinominati su GitHub. Se l'updater o le URL dei bug report puntano a un
repo inesistente, quelle funzioni si rompono.

La rinomina richiede un permesso che va oltre i permessi di contenuto del repository: con un
token fine-grained senza `Administration: read-write` la API risponde 403
`Resource not accessible by personal access token`, anche se il token ha `admin=true` sui
permessi di contenuto. Senza quel permesso la rinomina va fatta dalla UI GitHub
(Settings > General > Repository name) o con un token adeguato.

## 6. Documentazione

- `lib/doc/*.md` e i corrispettivi bilingui: nomi, identificatori, rimozione della card RFID,
  icona senza testo
- `README.md`: titolo in "mgws_inventory" e i tre badge di distribuzione, che contengono
  l'ID Android e il repo GitHub
  - Play: `id=it.mgws.mgws_inventory`
  - F-Droid: `it.mgws.mgws_inventory`
  - Obtainium: repo GitHub -> `mgws-inventory`
- `lib/doc/installation.md`: URL del repository dell'app -> `mgws-inventory`
- `lib/doc/integrazioni.md`: URL del repository companion del plugin ->
  `mgws-inventory-wordpress-plugin`
- `todo.md`: i rischi residui che restano aperti dopo il lavoro

I tre badge indicano "Coming soon", quindi non esistono listing pubblici con il vecchio ID:
cambiare `applicationId` non lascia schede pubbliche da correggere.

## 7. Commit

Repository separati, quindi due storie separate. Nell'app un commit per preoccupazione:

1. nomi visibili (traduzioni e metadati di piattaforma)
2. identificatori tecnici (package, ID, bundle, updater)
3. icone

Nel plugin:

4. nome, slug, text domain, pot, URL

In `docker/`:

5. `docker wordpress update` (unico, regola 15)

## 8. Verifica

- `flutter analyze` senza errori
- `flutter gen-l10n` e `dart run lib/traduzioni/verifica_traduzioni.dart` verdi
- `flutter test` senza regressioni rispetto allo stato noto (la suite ha gia fallimenti
  documentati in `todo.md`)
- app in esecuzione: titolo AppBar, titolo pagina web, icona senza testo, card della home che
  reggono il cambio lingua
- plugin: i test PHP esistenti e un controllo che il text domain nuovo risolva

## 9. Rollback

Ogni passo e un commit, quindi il ripristino e `git revert` del commit interessato. Sul lato
plugin il rollback operativo e rimettere la cartella con lo slug precedente e riattivare il
vecchio plugin, senza lanciare la disinstallazione.
