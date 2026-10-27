# Piano: tasto "Feedback / Aiuto" nella barra della home → issue GitHub

## Obiettivo

Nella AppBar della home (`lib/home/home.gui.dart`, `actions:` accanto a
`NotificationBell` e `_buildLogButton()`) aggiungere un tasto **Feedback**
che apre un modulo e crea una issue su
`github.com/Vincenzoferrara/mgws-inventory`, **senza mai inviare dati
sensibili** (dominio del negozio, URL, password, token, chiavi API, email,
nomi di clienti/dipendenti, IP).

## Decisione chiave: come si crea la issue

| Opzione | Come funziona | Pro | Contro |
|---|---|---|---|
| **A. URL precompilato** (consigliata per la v1) | L'app apre `…/issues/new?template=…&title=…&body=…&labels=…` con `url_launcher`; l'utente preme "Submit" su GitHub | Nessun token nell'app, nessun server, ok per F-Droid/GPL; l'utente vede esattamente cosa invia | Serve un account GitHub; un clic in più; URL max ~8 KB |
| B. Proxy (Cloudflare Worker / GitHub App) | L'app fa POST a un piccolo servizio che tiene il token e chiama l'API GitHub | Davvero automatico, niente account GitHub | Server da mantenere, anti-spam/rate-limit, privacy policy da aggiornare |
| C. Token nell'app | — | — | **Da escludere**: un token in un'app open source viene estratto in minuti |

Proposta: implementare **A** subito, con il servizio di invio dietro
un'interfaccia (`FeedbackSender`) così da poter aggiungere **B** in seguito
senza toccare la GUI.

## Il repository è pubblico

Ogni issue è leggibile da chiunque, viene indicizzata dai motori di ricerca
e la cronologia delle modifiche resta visibile: un dato sfuggito non si
può davvero "ritirare". Conseguenze sul piano:
- l'anteprima del testo finale è **obbligatoria**: non si invia senza
  averla vista;
- i log restano **spenti di default** e, se attivati, solo
  warning/error e al massimo ~50 righe;
- nel modulo, per il tipo "problema di sicurezza", nessuna issue: si apre
  invece la segnalazione privata
  `…/mgws-inventory/security/advisories/new` (come già indica
  `bug_report.yml`);
- nessun identificativo stabile (ID dispositivo, ID installazione) nel
  testo, per non rendere collegabili tra loro le issue dello stesso
  negozio;
- con la fase 2 (proxy) le issue partono a nome di un bot pubblico: serve
  rate-limit e filtro anti-spam, altrimenti chiunque può riempire il
  repo.

## Regola privacy: allowlist, non blacklist

Il report contiene **solo campi scelti esplicitamente**; nulla viene preso
"in blocco" dallo stato dell'app.

Inclusi automaticamente:
- versione e build (`package_info_plus`), piattaforma e versione OS,
  lingua dell'app, tipo di login (WordPress Admin / JWT / chiavi Woo / smart
  card — solo il *tipo*), plugin MGWS presente sì/no e versione, sezione
  aperta al momento del clic.

Mai inclusi:
- `currentSiteUrl` / dominio, nome negozio, nome utente e avatar, email,
  password, JWT, consumer key/secret, application password, IP, nomi di
  clienti/ordini/prodotti.

Opzionale (casella **disattivata** di default): ultime N righe di log
(solo livello warning/error) prese da `AppLogger.memoryLogContent`, che
passano per un secondo filtro più severo (vedi sotto).

## Passi

1. **Servizio dati** — `lib/feedback/feedback_report.dart`
   - classe `FeedbackReport` (tipo: bug / suggerimento / domanda, titolo,
     descrizione, info tecniche, log opzionale);
   - `FeedbackReport.toMarkdown()` con lo stesso ordine dei campi di
     `.github/ISSUE_TEMPLATE/bug_report.yml`.

2. **Sanitizzatore dedicato** — `lib/feedback/feedback_sanitizer.dart`
   - riusa i pattern di `AppLogger._sensitivePatterns` (spostandoli in una
     costante condivisa invece di duplicarli);
   - aggiunge: sostituzione **esatta** del dominio corrente
     (`HomeCode.currentSiteUrl` con e senza `www.`/schema) → `<sito>`;
     regex generiche per URL/hostname, email, IPv4/IPv6, numeri di telefono,
     IBAN/carte; nome utente e display name noti → `<utente>`;
   - si applica sia alla descrizione scritta dall'utente sia ai log;
   - test unitari in `test/feedback_sanitizer_test.dart` con casi reali
     (log di login, errori Dio con URL, ecc.).

3. **Invio** — `lib/feedback/feedback_sender.dart`
   - interfaccia `FeedbackSender` + `GithubUrlFeedbackSender` (opzione A):
     costruisce l'URL con `Uri.https(...)` e `queryParameters`, tronca il
     log per stare sotto ~7 KB, apre con
     `launchUrl(mode: LaunchMode.externalApplication)`;
   - fallback se il browser non si apre: pulsante "Copia testo" negli
     appunti + link alla pagina issues;
   - repository letto da una costante unica (oggi `_issuesUrl` in
     `about_settings.gui.dart` → spostarla in un file condiviso).

4. **GUI** — `lib/feedback/feedback_dialog.gui.dart`
   - dialog (bottom sheet su smartphone) con: tipo, titolo, descrizione,
     casella "allega log tecnici";
   - **anteprima** del testo finale già sanitizzato, modificabile, prima
     di inviare: l'utente vede esattamente cosa esce dall'app;
   - avviso fisso: "Non scrivere password, dominio o dati dei clienti".

5. **Tasto nella barra** — `lib/home/home.gui.dart`
   - `_buildFeedbackButton()` accanto a `_buildLogButton()`, icona
     `Icons.feedback_outlined`, tooltip localizzato;
   - su schermo piccolo resta solo l'icona (come `NotificationBell compact`).

6. **Localizzazione** — chiavi nuove in `lib/l10n/app_it.arb` e
   `app_en.arb` (titolo, campi, avviso privacy, errori) e rigenerazione.

7. **Lato GitHub**
   - template `.github/ISSUE_TEMPLATE/app_feedback.yml` (o riuso di
     `bug_report.yml` via `?template=`) e label `from-app`;
   - aggiornare `PRIVACY.md`: cosa contiene il feedback e che parte solo
     su azione dell'utente.

8. **Verifica**
   - test del sanitizzatore + test del builder dell'URL (lunghezza, encoding);
   - prova manuale su Linux e Android: URL aperto, nessun dominio/nome
     utente nel testo, fallback "Copia" funzionante.

## Fase 2 (facoltativa): invio senza account GitHub

Cloudflare Worker con token di una GitHub App (permesso solo
`issues:write` su quel repo), rate-limit per IP, dimensione massima,
label `from-app`. Nell'app basta aggiungere `ProxyFeedbackSender` e una
scelta in Impostazioni. Il sanitizzatore resta lato app (e ripetuto nel
Worker come seconda barriera).

## Domande aperte

- Va bene la v1 con URL precompilato (serve un account GitHub), o serve
  subito la fase 2?
- Il tasto deve comparire anche prima del login (es. "non riesco ad
  accedere")? Proposta: sì, con meno info tecniche.
