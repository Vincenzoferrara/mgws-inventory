# Traduzioni

Tutto il codice di traduzione dell'app sta in questa cartella. Nessun file di
traduzione deve stare altrove nel progetto.

## Come funziona

L'app usa il sistema ufficiale di Flutter: `flutter_localizations` con file ARB
e generazione di codice tipizzato. Non c'e nessun pacchetto di terze parti a
runtime.

- `app_en.arb` e il **template**: ogni chiave nasce qui ed e in inglese
- `app_it.arb` contiene le traduzioni italiane
- `generato/` contiene il codice prodotto da `flutter gen-l10n`, non va
  versionato
- `l10n.yaml` (nella root del progetto) collega tutto: dice a Flutter dove
  leggere gli ARB e dove scrivere il codice generato

Le stringhe si leggono nel codice con `context.l10n.<chiave>`. Il vantaggio e
che una chiave sbagliata e un **errore di compilazione**, non un testo a caso
mostrato all'utente.

## Lingue supportate

Oggi solo italiano e inglese. Per aggiungerne una:

1. crea `app_<codice>.arb` in questa cartella, con le stesse chiavi del template
2. traduci i valori
3. aggiungi il codice a `preferred-supported-locales` in `l10n.yaml`
4. aggiungi il codice a `LocaleSettings.supportate` in `locale_settings.dart`
5. esegui `flutter gen-l10n` e `dart run lib/l10n/check_translations.dart`

La lingua predefinita segue l'impostazione del sistema operativo. L'utente puo
forzarla in **Impostazioni > Generale > Lingua**.

## Regole per le chiavi

- **in inglese**, sempre, anche se il valore di default e italiano
- `camelCase`, prefissate dal modulo: `cassaFisica`, `inventoryHintChooseModule`
- niente punti e niente oggetti annidati: `gen_l10n` accetta solo nomi di metodo
  Dart validi
- ogni chiave ha un `@<chiave>` con la `description`, che serve a chi traduce
  senza vedere il codice

## Aggiungere una stringa

1. aggiungi la chiave e il valore in `app_en.arb`
2. traduci in `app_it.arb`
3. usa `context.l10n.<chiave>` nel widget
4. esegui `flutter gen-l10n` e `dart run lib/l10n/check_translations.dart`

Se il widget non ha un `BuildContext` (per esempio dentro un `ChangeNotifier` o
un formato), passa la stringa tradotta dal widget che chiama: non mettere la
traduzione dentro la classe.

## Cosa non si traduce

- i dati inseriti dagli utenti: nomi prodotto, clienti, fornitori, note
- le chiavi di persistenza e i nomi dei campi del protocollo (WooCommerce, MGWS,
  WordPress): cambiarne uno romperebbe i dati gia salvati
- i messaggi di log

### `lib/importer/` non e ancora tradotto

Il modulo di importazione CSV e escluso di proposito, per decisione presa durante
l'introduzione dell'i18n. I nomi delle colonne del CSV non sono semplicemente
etichette: sono gli identificatori con cui l'app riconosce ogni campo del
template di importazione di WooCommerce. Tradurli romperebbe l'importazione dei
prodotti.

Le stringhe di quell'interfaccia quindi restano in italiano. Se in futuro le si
vuole tradurre, va prima deciso come gestire i messaggi di validazione, che
nascono in `csv_product_parser.dart` senza un `BuildContext` e vengono mostrati
all'utente: servono o una chiave di errore al posto del testo, o il passaggio
delle traduzioni dentro il parser.

## Numeri, importi e date

Non usare formati fissi come `NumberFormat.currency(locale: 'it_IT')`: prendi la
lingua dal contesto con `Localizations.localeOf(context)` cosi importi e date
seguono la lingua scelta.

## Attributi delle varianti prodotto

I nomi canonici degli attributi sono **in inglese**: `size` e `color`. I
cataloghi creati prima possono avere attributi chiamati `taglia` e `colore`: per
questo l'utente puo collegare i canonici agli attributi gia presenti nel suo
catalogo, in **Impostazioni**, senza rinominare nulla.

La logica sta in `attribute_map.dart`.

## Verifica in CI

`.github/workflows/check-translations.yml` gira su ogni push e su ogni pull
request e si ferma se:

- una chiave del template non ha una traduzione
- una traduzione contiene una chiave che il template non ha piu
- un valore e vuoto
- i placeholder usati nella traduzione non corrispondono a quelli del template

Questo rende sicuro tradurre: basta aprire una pull request modificando un file
JSON, e la CI garantisce che la traduzione sia completa.

## Comandi utili

```bash
flutter gen-l10n                              # rigenera le classi
dart run lib/l10n/check_translations.dart   # controlla le traduzioni
```
