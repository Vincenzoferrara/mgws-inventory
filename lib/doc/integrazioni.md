# Integrazioni

## Supportate

- WooCommerce
- MGWS
- Smartcard NFC/USB
- CalDAV
- RFID
- Provider IA configurabili

## Flusso backend

- I provider diretti dell'app sono solo WooCommerce e MGWS
- WooCommerce resta il canale diretto per catalogo, ordini ecommerce nativi, clienti e funzioni Woo standard
- MGWS gestisce checkout POS, resi/cambi vincolati, turno cassa server-side opzionalmente obbligatorio, impostazioni POS globali, impostazioni utente app, dipendenti gestionali con stipendio in centesimi/valuta e collegamento opzionale a `wp_user_id`, permessi dei dipendenti collegati, stock gestionale, carico rapido, fornitori, riordino, ordini fornitore, ricezione/convalida, movimenti, inventario fisico e loyalty v1
- I fornitori sono record MGWS nella tabella `mg_fornitori`; l'app li legge tramite `/wp-json/mgws/v1/inventory/suppliers`. Non vengono creati utenti WordPress o customer WooCommerce, quindi la lista Clienti resta composta solo dai clienti Woo.
- Il costo di acquisto corrente usa il meta Woo `_purchase_cost` su prodotto o variante; MGWS lo aggiorna quando una ricezione fornitore viene convalidata.
- Sedi, magazzini e ubicazioni operative sono esposte da MGWS con `/inventory/sites`, `/inventory/warehouses` e `/inventory/locations`.
- MGWS espone anche le rotte per aggiunta prodotti e rettifica: `POST /wp-json/mgws/v1/inventory/quick-load` per il carico e `PUT /wp-json/mgws/v1/inventory/stock/reconcile` per la rettifica motivata
- La cassa legge e aggiorna le impostazioni POS globali con `GET/PUT /wp-json/mgws/v1/pos/settings`, apre il turno con `POST /wp-json/mgws/v1/pos/shifts` prima di salvarlo localmente, invia `POST /wp-json/mgws/v1/pos/checkout` con righe vendita, righe reso, cliente, metodi di pagamento, totali, meta e riferimento turno (`shift_id`/`_turno_id`) quando presente, e chiude il turno con `POST /wp-json/mgws/v1/pos/shifts/{shift_key}/close`
- MGWS blocca il checkout POS senza uno shift aperto server-side solo quando `turno_obbligatorio` e attivo; l'app usa `turno.id` come `shift_key` server e non apre o chiude localmente il turno se MGWS rifiuta la richiesta
- MGWS crea l'ordine WooCommerce, registra i movimenti in `mg_stock_moves`, aggiorna `mg_stock_levels` e restituisce `order_id` o `woo_order_id`
- `mg_stock_levels` e la sorgente autorevole dello stock; lo stock WooCommerce e una proiezione sincronizzata
- L'ID ordine WooCommerce restituito dal checkout e il riferimento ordine della vendita POS; meta ordine MGWS e `mg_stock_moves` conservano l'audit operativo
- Nel flusso creazione o modifica prodotto, l'app puo chiamare `PUT /wp-json/mgws/v1/inventory/stock/reconcile` dopo il salvataggio WooCommerce per impostare lo stock gestionale totale finale con motivo auditato.
- `InventoryGlobal.reconcileInventory(fixDiscrepancies)` confronta WooCommerce e MGWS e produce proposte; non corregge stock in automatico. Le correzioni operative passano da conte fisiche approvate o da endpoint MGWS di mutazione validati.
- L'app non richiama direttamente plugin terzi come ATUM o myCred; se un sito li usa, la scelta resta interna a MGWS
- Le letture delle varianti WooCommerce passano dal metodo `getProductVariations` della libreria ufficiale `woocommerce_flutter_api` v2; gli errori vengono registrati e rilanciati senza trasporti alternativi.
- Le mutazioni delle varianti WooCommerce passano dal metodo `batchUpdateProductVariations`.
- La libreria `woocommerce_flutter_api` v2 utilizza `consumerKey`/`consumerSecret` per l'autenticazione, enum `WooSort`/`WooOrderBy` per l'ordinamento, e restituisce `WooPage<T>` per i risultati paginati. I metodi `updateXxx(id, item)` e `deleteXxx(id)` richiedono l'ID come primo parametro.

## MGWS v1 implementato

- POS: `POST /wp-json/mgws/v1/pos/checkout` e registrato e crea ordini WooCommerce con audit stock
- Idempotenza POS: `idempotency_key` nel payload e la chiave primaria; in assenza, MGWS usa il meta `_id_scontrino_locale`; senza chiave il checkout resta compatibile ma non ha garanzia di replay
- Turno cassa: `GET/PUT /pos/settings` espone `turno_obbligatorio` globale; quando attivo l'app apre `POST /pos/shifts` con `shift_key`, usa la stessa chiave come `shift_id` nel checkout, e chiude `POST /pos/shifts/{shift_key}/close` inviando solo contanti/carta contati. MGWS calcola `expected_totals` dagli ordini collegati e restituisce differenze. Checkout senza shift aperto valido server-side viene rifiutato solo con turno obbligatorio attivo.
- Resi/cambi POS: le righe reso inviano `source_sale_id`, `source_line_key`, `return_reason` e `return_outcome`; MGWS valida origine e residuo rendibile quando i riferimenti sono presenti e rifiuta oltre-residuo con `409`.
- Impostazioni utente: `GET/PATCH /wp-json/mgws/v1/me/settings` sincronizza le preferenze non segrete dell'app per l'utente WordPress autenticato; token, password, secret e chiavi sensibili restano esclusi dalla sync normale.
- Dipendenti: `GET/POST /wp-json/mgws/v1/employees` e `GET/PATCH/DELETE /wp-json/mgws/v1/employees/{id}` gestiscono anagrafiche dipendenti MGWS con `wp_user_id` opzionale, stipendio in `salary_cents` + `salary_currency`, e cancellazione come disattivazione.
- Permessi dipendenti: l'app usa `GET/PATCH /wp-json/mgws/v1/users/{wp_user_id}/permissions` solo partendo da un dipendente MGWS collegato. Non usa una lista generica di utenti WordPress per assegnare capability a persone non presenti in anagrafica dipendenti.
- Credenziali dipendenti: l'app usa `GET /wp-json/mgws/v1/users/{wp_user_id}/app-passwords` e `GET /wp-json/mgws/v1/users/{wp_user_id}/woo-keys` in sola lettura, e le rotte `DELETE` corrispondenti per la revoca. Non genera credenziali: l'Application Password del dispositivo e gia provisionata dal flusso di login wp-admin e le chiavi WooCommerce si creano da wp-admin. Queste rotte richiedono `mgws_manage_credentials`, riservata all'amministratore, quindi un 403 va trattato come "richiede account amministratore" e non come errore bloccante della scheda dipendente.
- Inventario in lettura: `inventory/status`, `inventory/stock/product/{productId}`, `inventory/stock/all`, `inventory/statistics` e `inventory/low-stock`
- Inventario operativo: `POST /wp-json/mgws/v1/inventory/stock/sync` sincronizza stock WooCommerce verso `mg_stock_levels`, `PUT /wp-json/mgws/v1/inventory/stock/reconcile` registra una rettifica motivata portando il prodotto a un valore assoluto, e `POST /wp-json/mgws/v1/inventory/rfid/scan` risolve tag o barcode senza mutare stock. `reconcile` accetta `product_id`, `correct_stock`, `reason` e `site_id`, e non ha un campo nota, quindi l'app accorpa i dettagli dell'operatore dentro il motivo con `inventoryMovementText`. `site_id` dichiara in quale sede viene scritto il totale e non viene mai dedotto: vale zero solo su un negozio con una sede sola, dove il totale del prodotto e il totale della sede sono lo stesso numero, e su un negozio con piu' sedi va dichiarato, altrimenti la rotta risponde con un errore invece di scrivere su tutte le sedi. Lo stesso vale per `stock/sync`, che altrimenti riverserebbe un unico numero di WooCommerce su un perimetro che quel numero non descrive. `POST /wp-json/mgws/v1/inventory/stock/move` trasferisce pezzi fra ubicazioni e non cambia il totale del prodotto: va usato per lo spostamento e per il suo annullamento, mai per la rettifica, perche' riaprire uno spostamento come rettifica produrrebbe una diminuzione che non e' mai avvenuta. Questa rotta ha invece i campi `note` e `to_room`, quindi su di lei i dettagli viaggiano separati dal motivo.
- Un movimento e' un insieme di righe, e per questo esiste una tabella di intestazioni (`mg_stock_movements`) con una `movement_key` unica. Tutte e tre le rotte di scrittura dell'app la accettano come parametro facoltativo: l'app invia una richiesta per riga di prodotto e la stessa chiave su tutte, il backend crea l'intestazione con la prima richiesta che arriva e la riusa per le altre. Serve perche' il ledger raggruppi per operazione e non per prodotto: senza, un carico di trenta codici apparirebbe come trenta carichi da un pezzo. La chiave e' opzionale perche' i flussi interni del plugin scrivono righe senza operatore e non hanno operazione da dichiarare; quelle righe restano senza intestazione e l'app le mostra una alla volta.
- Carico e rettifica: `POST /wp-json/mgws/v1/inventory/quick-load` riceve prodotto o variante, quantita positiva, motivo, nota opzionale e chiave idempotente. `warehouse_id`, `room`, `rack` e `shelf` sono opzionali e assenti dal payload quando vuoti; se nessuna ubicazione risolve il prodotto, MGWS usa il primo magazzino valido consentito e conserva vuoti stanza, scaffale e ripiano. Non accetta come requisito fornitore, ordine, fattura o DDT. Crea un movimento `load` auditato solo dopo conferma utente e risposta MGWS valida.
- Fornitori: le rotte supplier MGWS gestiscono elenco, dettaglio, creazione, aggiornamento e inattivazione del registro `mg_fornitori`; l'anagrafica vive nella tabella MGWS e il fornitore non e' legato a nessun utente WordPress o customer WooCommerce. Il nome e' l'unico dato obbligatorio, l'email e' facoltativa. I fornitori sono globali: nessuna rotta supplier accetta o richiede `site_id`. Sono stock-neutral.
- Riordino: le rotte reorder MGWS leggono regole e suggerimenti da sottoscorta, permettono defer/snooze e creano bozze ordine quando richiesto. Non mutano stock.
- Ordini fornitore: le rotte purchase-order MGWS gestiscono bozze, righe prodotto/variante, stato, date, costi e cancellazione. Ordini e righe restano stock-neutral fino alla ricezione convalidata.
- Ricezione/convalida: le rotte receipt MGWS gestiscono bozze, righe ricevute, respinte, backorder, motivi, `pending_verification` e `convalida`. Solo la convalida/post cambia `mg_stock_levels`; se la ricezione e in verifica serve `mgws_purchase_approve`. La convalida aggiorna anche `_purchase_cost` sul prodotto o sulla variante ricevuta.
- Movimenti: le rotte movement MGWS leggono il ledger autorevole `mg_stock_moves`, con filtri e dettaglio. Le rotte di lettura sono read-only e il ledger non espone ne una `DELETE` ne una `UPDATE`: un movimento registrato non si modifica e non si cancella.
- Annullamento di un movimento: non esiste una rotta che lo faccia, e non deve esserci perche' il ledger e' la prova di quello che e' successo al magazzino. L'app registra quindi un movimento nuovo accanto a quello originale, con il numero dell'originale nel motivo, e le due righe restano entrambe nel ledger: chi legge vede il fatto e il suo annullamento. Per un movimento che cambia il totale e' un contromovimento con `PUT /wp-json/mgws/v1/inventory/stock/reconcile`, che riporta ogni prodotto allo `stock_before` del movimento originale. Il contromovimento parte solo se lo stock letto adesso e' ancora uguale a `stock_after`: se nel frattempo qualcun altro ha mosso il prodotto, quella riga viene bloccata e mostrata all'operatore invece di azzerare anche l'altra operazione.
- Lo spostamento si annulla in modo diverso, perche' non cambia il totale: riportare i pezzi indietro non e' un contromovimento ma un *altro* spostamento, fatto con `POST /wp-json/mgws/v1/inventory/stock/move` e la rotta capovolta. Passare da `reconcile` azzererebbe il totale del prodotto togliendogli pezzi che sono invece spostati in un altro magazzino. La rotta si ricava dalle righe del movimento originale, che portano `warehouse_from`, `warehouse_to` e la sede di ciascun lato; senza rotta l'annullamento non e' offerto, perche' tirare a indovino su dove mettere la merce e' peggio di non farlo. Vale anche il controllo che nel magazzino di arrivo ci siano ancora i pezzi da riportare indietro.
- Conteggi fisici MGWS: le rotte `count-sessions` gestiscono creazione, elenco, dettaglio, patch, righe, discrepanze e approvazione. Le righe possono risolvere un barcode/tag gia noto ma restano bozze e non modificano stock.
- L'approvazione di una sessione applica solo le discrepanze auditabili a `mg_stock_levels`, crea movimenti `adjust` collegati alla sessione e alla riga, e rende la sessione immutabile.
- Le griglie Flutter per fornitori, riordino, ordini, ricezioni, movimenti e conte usano la `DataGridView` condivisa sotto `lib/reuse_class/datagridview/`.
- Loyalty: stato servizio, scheda cliente, lookup carta, lookup email, creazione o modifica carta, cancellazione carta, aggiunta punti, sottrazione punti, storico e statistiche
- Cancellare una carta loyalty rimuove il numero carta dal conto MGWS, mantiene conto cliente e storico movimenti, e risponde `404` se la carta manca
- Lo storico loyalty e append-only, paginato e ordinato dal movimento piu recente
- Report: `POST /wp-json/mgws/v1/reports/query` risponde a una domanda fatta di misura, suddivisione facoltativa e filtri, aggregando in SQL gli scontrini MGWS (righe IVA inclusa, sconto di testata ripartito sulle righe, annullati esclusi, resi negativi) e le righe degli ordini online dalle tabelle analytics WooCommerce, escludendo gli ordini creati dalla cassa. Le fasce orarie seguono il fuso del negozio, ora legale compresa. `GET /wp-json/mgws/v1/reports/catalog` elenca misure, suddivisioni, filtri e valori noti (casse, operatori, metodi di pagamento). Entrambe richiedono `mgws_reports_read`, `manage_woocommerce` o `manage_options`; le risposte restano in cache 120 secondi.
- Dashboard: `GET /wp-json/mgws/v1/dashboards`, `PUT` e `DELETE /wp-json/mgws/v1/dashboards/{id}` salvano le dashboard personali e quelle condivise con tutti o solo con i gestori.

## MGWS v1 compatibilita

- Le richieste POS senza chiave idempotente sono accettate per compatibilita, ma non proteggono da invii duplicati
- Le operazioni inventario richiedono payload validi e restituiscono errori MGWS visibili nell'app quando il backend rifiuta o non completa la richiesta

## Sicurezza MGWS

- Le rotte richiedono utente WordPress autenticato; assenza login restituisce `401`
- Le rotte richiedono capability MGWS o capability amministrative WooCommerce/WordPress secondo il contratto route; permessi insufficienti restituiscono `403`
- Parametri numerici, lookup carta/email, payload inventario e chiave idempotente hanno validazione lato REST e nei handler
- Gli errori pubblici non devono esporre SQL, token, password, path locali o dati di altri clienti

## WooCommerce diretto

- `WooQueryTasse.getTaxRates(country/state)` applica i filtri `country` e `state` lato client perche l'endpoint WooCommerce delle tax rates non filtra per questi campi; quando filtra, pagina tutte le aliquote e poi restituisce la pagina locale richiesta.

## Login

- JWT
- WooCommerce API con Consumer Key e Secret
- Smartcard

### Login JWT

- Prima di inviare username e password, il connettore JWT verifica che almeno una route JWT nota risponda e non sia assente (`404`).
- Se tutte le route JWT note sono assenti, il login JWT fallisce senza inviare le credenziali al backend.
- La verifica non crea uno stato persistente di disponibilita JWT: serve solo a decidere se tentare quel login.
- Il login WooCommerce API con Consumer Key e Secret non dipende dal plugin JWT e resta utilizzabile anche quando le route JWT mancano.

## Disponibilità MGWS

- `WooConnect` è l'unico owner dei connettori di autenticazione: espone `siteUrl` e `getAuthenticatedDio()` con le credenziali del connettore in uso, e tutte le query MGWS costruiscono le richieste su quel transport. Le rotte MGWS viaggiano quindi con le stesse credenziali della sessione attiva, in qualunque modalità di login.
- Non esiste un connettore secondario per MGWS né un tentativo di connessione alternativo: senza sessione attiva la richiesta non parte e l'errore resta in chiaro.
- Dopo ogni connessione riuscita, in tutte e tre le modalità (JWT, WordPress Basic Auth con Application Password, WooCommerce API con Consumer Key/Secret) e dopo l'auto-connessione, l'app verifica i servizi MGWS con `MgwsAvailability` in `login/jwt_api/query_mgws/`.
- La disponibilità si legge dal corpo della risposta di `inventory/status` e `loyalty/status`, non dal solo status HTTP: le rotte rispondono 200 anche con il servizio spento e `enabled`/`ok` a `false`, per esempio con le tabelle MGWS non installate.
- L'auto-connessione WordPress verifica MGWS al riavvio dell'app, quindi riaprire l'app dopo un login wp-admin non lascia i moduli MGWS chiusi.
- In modalità Consumer Key/Secret le chiavi WooCommerce autenticano solo le rotte `wc/`: MGWS risponde 401 e l'app degrada MGWS come non disponibile. MGWS richiede un utente WordPress, quindi le rotte MGWS sono disponibili con login JWT o WordPress.
- Lo stato centralizzato è disponibile con `PlatformManager.isMgwsAvailable` e `LoginCode.isMgwsAvailable`; `refreshMgwsAvailability()` riesegue la stessa verifica quando serve esplicitamente.
- Lo stato centralizzato è disponibile con `PlatformManager.isMgwsAvailable` e `LoginCode.isMgwsAvailable`; `refreshMgwsAvailability()` riesegue la stessa verifica quando serve esplicitamente.
- Endpoint mancanti, plugin MGWS non installato o errori di rete impostano lo stato a `false` senza annullare la connessione WooCommerce riuscita.
- Logout, disconnessione, auto-connessione non riuscita, test WooCommerce fallito e ri-autenticazione forzata azzerano lo stato MGWS.
- Le operazioni POS, inventario, loyalty e utenti MGWS consultano lo stato prima della richiesta e restituiscono il valore sicuro previsto dal rispettivo contratto quando MGWS non è disponibile.
