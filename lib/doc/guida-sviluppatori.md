# Guida Sviluppatori

## Stack

- Flutter + Dart
- `provider` per lo stato
- `docking` per il layout desktop
- `shared_preferences` e `flutter_secure_storage` per la persistenza
- `dio` e `http` per le API

## Struttura codice

- Ogni modulo principale vive in una cartella dedicata sotto `lib/`
- Ogni modulo separa sempre `.gui.dart` e `.code.dart`
- `.gui.dart` contiene solo widget, layout, input e rendering
- `.code.dart` contiene orchestrazione, stato e logica di schermata
- `lib/reuse_class/` contiene solo componenti usati in piu schermate
- `lib/reuse_class/barcode/` contiene lo scanner barcode/QR condiviso: grafica, fotocamera, lettura ed elaborazione restano nel modulo riusabile; i caller usano `showBarcodeScanner(context)` e ricevono solo `String?`. Lo scanner usa `flutter_zxing`, basato su ZXing C++, per mantenere la lettura barcode/QR compatibile con build FOSS/F-Droid senza dipendere da ML Kit
- `lib/reuse_class/barcode/barcode_generator.dart` contiene il generatore barcode condiviso: `BarcodeGenerator.generaCode128(esclusi: ..., random: ..., now: ...)` produce un valore numerico di 30 cifre compatibile Code128 (13 cifre casuali + data/ora attuale `DDMMYYYYHHMMSS` + millisecondi), evita i valori esclusi e valida tramite il plugin `barcode`; `random`/`now` sono iniettabili per i test deterministici. Usato dall'editor prodotti, ma pensato per qualunque modulo che debba generare un barcode interno
- `lib/reuse_class/device_utils/device_utils.dart` contiene `DeviceUtils`: `isSmartphone`, `isTablet` e `isDesktop` classificano il dispositivo dalla dimensione piu corta dello schermo, mentre `isMobilePlatform` e `isDesktopPlatform` leggono la piattaforma corrente
- `login/jwt_api/` contiene il layer di integrazione con le piattaforme esterne
- `settings/` contiene la pagina madre delle impostazioni e le singole visualizzazioni settings dei moduli

## Entry point

- `lib/main.dart` inizializza logger, tema e `MaterialApp`
- `lib/home/home.gui.dart` costruisce la UI principale e le sezioni
- `lib/home/home.code.dart` gestisce login gate, mobile/desktop, tab docking e lettura versione runtime tramite `package_info_plus`
- `lib/cassa/cassa.code.dart` delega il checkout POS a MGWS
- `lib/login/jwt_api/query_mgws/query_mgws_pos.dart` parla con `/wp-json/mgws/v1/pos/checkout`

## Logging applicativo

- `lib/log_viewer/app_logger.dart` espone il singleton globale `log`, usato con `log.d`, `log.i`, `log.w`, `log.e`, `log.v` e `log.f`.
- Il logger mantiene sempre un buffer circolare temporaneo in memoria, visibile dalla schermata `Visualizza Log`, senza creare file al solo avvio dell'app.
- La scrittura su file e solo temporanea e parte su richiesta dell'utente dalla schermata log. I file vengono creati sotto la directory temporanea dell'app in `mgws_inventory_logs`, non in `Documents`, `Download` o cartelle utente permanenti.
- Il viewer puo creare uno snapshot temporaneo per la condivisione; dopo la condivisione il buffer memoria e i file temporanei vengono svuotati.
- La sanitizzazione viene applicata a messaggio, errore e stack trace per tutti i livelli: password, token, JWT, Bearer token, API key, app password, secret e consumer key/secret non devono comparire nei log condivisi.
- I log devono passare da `log.*` e non da `print` o `debugPrint`, cosi restano filtrabili nel viewer e attraversano la sanitizzazione centrale.
- Il formato leggibile e `HH:mm:ss.SSS [LIVELLO] [tag] messaggio`; lo stack trace viene scritto come blocco indentato dopo la riga principale.
- `clearAllLogs()` svuota buffer memoria e file temporanei. `getAllLogFiles()` elenca solo i file temporanei non scaduti della cartella log dell'app.

## Flusso auth

- `lib/login/gui/login.gui.dart` gestisce il form di accesso
- `lib/login/gui/login.code.dart` normalizza l'URL e chiama il connettore WooCommerce
- `lib/login/auth_connector.dart` definisce il contratto `AuthConnector` che ogni connettore di autenticazione implementa
- `WooConnect` e' l'unico owner dei connettori: espone `siteUrl` e `getAuthenticatedDio()` con le credenziali del connettore in uso. Nessun altro punto dell'app deve istanziare un connettore per autenticarsi, perche' un connettore secondario risulterebbe disallineato dalla sessione realmente in uso e le rotte MGWS diventerebbero irraggiungibili
- `JwtConnect.connect()` controlla l'esistenza di una route JWT prima di inviare username e password; se il plugin JWT manca, il login JWT fallisce senza spedire credenziali
- Il controllo JWT non mantiene stato applicativo e non condiziona il login WooCommerce API con Consumer Key e Secret
- `login/jwt_api/query_mgws/mgws_availability.dart` conserva la disponibilità centrale di MGWS dopo i controlli sicuri di inventario e loyalty; il suo esito non modifica l'esito della connessione WooCommerce
- `PlatformManager.isMgwsAvailable` e `LoginCode.isMgwsAvailable` sono i soli riferimenti di stato per schermate e controller MGWS; non devono ripetere chiamate dirette agli endpoint di stato
- `lib/home/home.gui.dart` decide solo la superficie di presentazione del login: sugli schermi stretti apre una route full-screen, sugli schermi grandi mantiene il dialog; la logica auth resta nel modulo `login/`
- Il login e il punto piu sensibile del progetto: ogni modifica deve essere valutata anche dal punto di vista sicurezza prima dell'implementazione
- I metodi di login futuri devono restare sicuri per default

## Backend e vincoli

- Le funzioni WooCommerce native parlano direttamente con WooCommerce
- MGWS gestisce checkout POS, inventario v1, loyalty v1, stock gestionale, restock, ricezioni, conte fisiche e movimenti custom
- L'app ha solo due provider WordPress diretti: WooCommerce e MGWS
- Il checkout POS crea l'ordine WooCommerce, registra i movimenti stock e risponde con `success`, `order_id` o `woo_order_id`, stato ordine, totali e righe processate
- Il payload POS deve inviare una chiave `idempotency_key` quando disponibile; MGWS accetta anche il meta legacy `_id_scontrino_locale` come fallback di compatibilita
- A parita di chiave e payload, MGWS restituisce la risposta salvata senza creare un secondo ordine o nuovi movimenti; a parita di chiave e payload diverso risponde `409 mgws_idempotency_conflict`
- L'app non deve dipendere da ATUM, myCred o plugin terzi in modo diretto
- WooCommerce resta il backend per il dominio ecommerce nativo
- MGWS resta il backend per la logica gestionale custom e per le regole non native di WooCommerce

## Contratto MGWS v1 per l'app

- `QueryMgwsPos` usa `GET/PUT /wp-json/mgws/v1/pos/settings` per leggere o aggiornare l'obbligatorieta globale del turno, `POST /wp-json/mgws/v1/pos/shifts` per aprire uno shift server-side, `POST /wp-json/mgws/v1/pos/checkout` per il checkout POS e `POST /wp-json/mgws/v1/pos/shifts/{shift_key}/close` per chiudere il turno con i soli valori contati
- Quando `turno_obbligatorio` e attivo, il checkout POS deve riferire uno shift MGWS aperto tramite `shift_id` root o meta `_turno_id`; senza shift valido MGWS risponde con errore 409 e l'app non deve aggirare il blocco. Quando e disattivo, il payload puo omettere il riferimento turno e MGWS non scrive meta `_mgws_shift_id` sull'ordine.
- `QueryMgwsUserSettings` sincronizza le preferenze non segrete dell'app con `GET/PATCH /wp-json/mgws/v1/me/settings`; la sync generica legge/scrive `SharedPreferences`, escludendo password, token, secret e chiavi sensibili
- `QueryMgwsEmployees` gestisce i dipendenti via `GET/POST /employees` e `GET/PATCH/DELETE /employees/{id}`; la UI non deve usare dati mock come fonte primaria e non deve creare nuove istanze scollegate del service per add/update
- I dipendenti serializzano lo stipendio come `salary_cents` intero e `salary_currency`; la UI deve validare l'importo e non usare fallback silenziosi a `0` per input non numerici
- I resi/cambi POS devono sempre inviare `source_sale_id`, `source_line_key` e `return_reason`; MGWS valida origine e residuo prima di accettare il checkout quando questi riferimenti sono presenti
- `QueryMgwsInventory` usa le rotte di lettura `status`, `stock/product`, `stock/all`, `statistics` e `low-stock`
- `QueryMgwsInventory` espone sync Woo verso MGWS, reconcile stock auditato e RFID scan resolve-only; lo scan RFID risolve tag o barcode e non muta quantita
- `QueryMgwsInventory` espone anche carico rapido, fornitori, riordino, ordini fornitore, ricezioni/convalida, movimenti, conte fisiche e rettifica tramite modelli tipizzati e gateway iniettabili
- Le schermate inventory mantengono UI e logica separate in file `.gui.dart` e `.code.dart`; i controller non chiamano Dio raw e passano sempre dal gateway MGWS tipizzato
- `InventoryAddProductsController` unifica Riordino e Ordini Fornitore in un unico flusso di aggiunta: in modalita semplice il carico e document-free, in modalita ordine le stesse righe documentano una bozza per il fornitore scelto. Il movimento di stock resta identico nelle due modalita, per cui aggiungere un fornitore non cambia la realta del magazzino.
- `InventoryRettificaController` prepara il comando `reconcileStock` con un motivo obbligatorio; muta stock solo dopo l'invio, mai in fase di preparazione o preview. Il verso della correzione e' una scelta della sezione, non della riga: le due radio stanno accanto alla spunta del modo rapido, cosi' sono visibili anche a lista vuota e rispondono alla domanda che l'operatore si fa mentre scansiona. Ogni riga ha solo il contatore dei pezzi, e togliere la spunta sostituisce il contatore con il conteggio assoluto, che vince su qualsiasi variazione
- `InventoryRettificaPlan` accetta piu righe e le invia una alla volta senza fermarsi al primo errore: `lastResults` raccoglie tutti gli esiti, perche' un operatore che corregge venti prodotti non deve ritentare tutta l'operazione perche' la terza riga ha fallito
- I tre pannelli operativi condividono `InventoryProductSection`, che possiede il campo barcode, il pulsante di ricerca, la spunta del modo rapido e la lista righe. Ogni modulo da' alla sezione il proprio nome della spunta e la propria chiave `keyPrefix`. Il campo `Dettagli` sta invece sulla pagina (`InventoryPage`) e i pannelli lo ricevono in sola lettura: e' un campo solo per un'operazione sola, e tre copie avrebbero significato tre posti in cui dimenticarlo
- `reconcile` non ha un campo nota: i dettagli dell'operatore finiscono dentro il motivo con `inventoryMovementText`, che accoda i dettagli solo se non sono gia' nel testo. `/stock/quick-load` ha invece una nota vera e propria, e la usa
- `InventoryModule` vive in `inventory_module.code.dart` e non nella pagina, perche' i pannelli devono poter dire quale modulo li rappresenta senza importare la pagina che li contiene. `writesStock` decide se il campo `Dettagli` ha senso; `canResumeFromLedger` dice se il modulo ha una rotta che sappia riprendere un movimento dall'esito. Le icone stanno nella pagina, non nell'enum: sono una scelta di schermata e il file dell'enum resta Dart puro
- Il ledger MGWS non espone ne `DELETE` ne `UPDATE`, e non deve esserci: e' la prova di quello che e' successo al magazzino. L'annullamento registra quindi un movimento nuovo accanto alla riga originale, e cambia rotta a seconda del tipo: per un movimento che cambia il totale e' un contromovimento con `stock/reconcile` che riporta ogni prodotto al suo `stock_before`; per uno spostamento e' uno spostamento al contrario con `stock/move` e la rotta capovolta, perche' un contromovimento azzererebbe il totale togliendogli pezzi che invece sono spostati. `InventoryMovementRevertController.prepare` verifica i due casi con controlli diversi e blocca, nominandola, ogni riga non lecita: sul contromovimento lo stock attuale deve coincidere con lo `stock_after` (azzerare anche un movimento successivo sarebbe un danno peggiore del movimento sbagliato), sullo spostamento il magazzino di arrivo deve avere ancora i pezzi da riportare indietro (tirarli fuori da un magazzino vuoto produrrebbe un totale negativo). Entrambe le verifiche fanno una lettura di rete per prodotto, quindi il pulsante resta spento fino a quando il piano non e' pronto
- Un movimento e' un insieme di righe, non una riga: MGWS scrive una riga per ogni prodotto toccato, quindi un carico di trenta codici sono trenta righe. Le app non puo' creare l'intestazione prima di sapere quante richieste andranno a buon fine, quindi ogni riga porta la stessa `movement_key` (`newInventoryMovementKey()`, una per invio e non per riga) e il backend crea l'intestazione con la prima che arriva e la riusa per le altre. Il raggruppamento segue `movementId`, che e' la chiave autorevole; `sourceType#sourceId` resta un ripiego per le righe senza intestazione e `riga#<id>` lascia da sola tutto il resto, perche' e' meglio una riga in piu' che due operazioni fuse. `_classify` guarda `stockEffect`, poi `sourceType`, poi `type`, in quest'ordine: vince il primo segnale e i piu' specifici sono testati per primi, cosi' una ricezione che contiene "move" nel nome non viene scambiata per uno spostamento. Un tipo non riconosciuto resta `InventoryMovementKind.altro` e mostra la parola grezza invece di essere travestito da un tipo noto: un'etichetta indovinata riaprirebbe il movimento nel pannello sbagliato
- Le righe di uno spostamento sono due per prodotto, una di uscita e una di entrata, con il delta che si annulla: `InventoryMovementGroup.products` le accorpa in un solo prodotto per codice, e il delta totale di uno spostamento e' quindi zero per costruzione. Mostrare `+0` accanto a venti pezzi spostati sarebbe un numero che non torna, e l'operatore lo leggerebbe come un errore: per lo spostamento la scheda mostra `movedQuantity` e la rotta `da -> a`
- MGWS pagina il ledger e `MgwsMovementFilter` non ha un filtro per documento, quindi un'operazione piu' grande di una pagina verrebbe spezzata in due righe. Il default sale a 100 righe e il pannello avvisa quando la risposta e' incompleta, invece di far notare il problema a metta. La soluzione vera e' un filtro backend
- Riprendere un movimento dal ledger vale per `Rettifica` e per `Sposta`. La rettifica si rifa dal valore assoluto che il movimento aveva lasciato; lo spostamento si rifa dalla rotta, che adesso MGWS scrive in ogni riga (`warehouse_from`/`warehouse_to`) e da cui l'app ricava anche le sedi, perche' lo stesso numero di magazzino puo' esistere in due sedi diverse. Un carico non e' riprendibile e non lo sara' mai: l'unica rotta che ha sa solo aumentare lo stock, e ridurlo significherebbe registrare una diminuzione spacciata per carico. Il blocco sta in `canResumeFromLedger`; sullo spostamento c'e' in piu' il controllo sulla rotta in `canResume`, perche' le righe scritte prima che la rotta fosse registrata non ce l'hanno
- Il seme di riapertura (`InventoryPanelSeed`) si consuma una volta sola, con un impronta (`stamp`): la pagina lo tiene per un frame e poi lo azzera. Senza quel consumed-check, tornare su un modulo dopo un altro ricaricherebbe il vecchio movimento senza che nessuno lo abbia chiesto
- Le righe seminate da un movimento riaperto usano il valore assoluto contato (`stockAfter`), non la delta: `reconcile` porta il prodotto a un valore assoluto, quindi applicare una variazione a uno stock gia' cambiato lo raddoppierebbe. Per questo il seme mette anche la spunta del modo rapico a false, e i prodotti rimossi dalla lista diventano ripristini espliciti nella stessa operazione (`InventoryRettificaRestoreLine`): toglierli dalla lista non basta a rimettere la merce a posto
- L'app non indovina il nome dell'operatore: `MgwsMovement` porta solo `operatorUserId` e l'unica rotta utente collegata e `users/me`, quindi la colonna operatore mostra l'identificativo numerico finche il backend non manda il nome
- Il carico rapido usa `InventoryQuickLoadCatalogController` come adapter inventory del caricamento progressivo di `ProdottiGestioneController`; i prodotti variabili sono gruppi non selezionabili e solo le varianti concrete diventano righe di carico. L'adapter protegge i callback progressivi quando il dialog viene chiuso e il controller e gia stato disposto.
- `InventoryQuickLoadCatalogController` espone `findByBarcode(String)`, che cerca prima sui prodotti semplici e poi sulle varianti; il risultato diventa una riga di carico con `toLine()`, evitando di creare righe con prodotti inesistenti quando il barcode non e in catalogo.
- Il catalogo mostra `immagineUrl` del prodotto o della variante con fallback variante-prodotto e filtra anche `metadatiCustom['barcode']`; i converter WooCommerce devono quindi reidratare `meta_data` sia sui prodotti sia sulle varianti.
- Durante il caricamento di una variante nell'editor `prodotti_crea` o del prodotto selezionato in `Prodotti > Gestisci`, solo nelle build debug il connettore WooCommerce registra il JSON REST completo della pagina e, per ogni variante, gli attributi JSON ricevuti insieme agli attributi `AttributoVariante` risultanti. Le voci usano rispettivamente i prefissi `PCREA_` e `PGEST_`; il prefetch delle altre righe della griglia non attiva il tracciamento. Il log serve a diagnosticare gruppi `Colore`/`Taglia` assenti.
- `InventoryQuickLoadController.submitPlan()` serializza le righe per rispettare il contratto MGWS a singola richiesta, conserva la chiave di idempotenza di ogni riga e restituisce risultati parziali e righe riprovabili. Magazzino e stanza sono condivisi, scaffale e ripiano appartengono alla riga; ogni valore di ubicazione vuoto viene omesso dal payload.
- `InventoryQuickLoadSettings` considera abilitato ciascun livello di ubicazione solo quando la relativa lista di opzioni non e vuota. Il pannello nasconde i livelli disabilitati e normalizza a vuoto eventuali valori di riga obsoleti prima di creare il piano di invio.
- Le tabelle inventory usano `DataGridView` da `lib/reuse_class/datagridview/`; non vanno creati grid o table bespoke per il ledger movimenti, le ubicazioni di un prodotto o i pannelli di magazzino
- `DataGridView.framed` (default `true`) decide se la griglia disegna la propria cornice. Va lasciato `true` quando la griglia e l'unico elemento decorato del riquadro che la ospita, come nelle pagine inventory. Va impostato `false` quando il contenitore ha gia un bordo: due cornici a pochi pixel di distanza si leggono come un bordo dentro un bordo e il padding della cornice toglie larghezza utile alle colonne, che su schermi stretti e la larghezza che rende leggibile il nome prodotto. La regola generale e una cornice per regione: dentro un riquadro gia bordato, le sezioni si separano con spazio o riempimento tonale, non con altri bordi
- `DataGridViewColumn.flexible` (default `false`) marca la colonna che incassa la larghezza residua: senza `fixedWidth` e con `minWidth` uguale a `width`. Serve a far arrivare la tabella al bordo destro invece di lasciare uno spazio morto quando tutte le colonne hanno larghezza fissa. Se in una griglia non c'e` nessuna colonna flessibile e la somma delle larghezze e` minore del riquadro, la tabella si ferma e lascia il residuo a destra
- Il menu contestuale della griglia vive nella `DataGridView`: `DataGridViewContextAction` (modello in `datagridview.code.dart`) descrive etichetta, icona e callback; `showDataGridViewContextMenu` (in `datagridview.gui.dart`) mostra il menu costruendo voci icona+etichetta ed eseguendo l'azione sulla riga. Sul click destro la griglia seleziona la riga e mostra il menu. I caller non costruiscono piu `PopupMenuItem` o `showMenu` propri per la griglia: forniscono solo le azioni e i callback applicati alla riga
- `GlobalPaginationBar` sta su una riga sola e la sua larghezza e un contratto, non una conseguenza. Tre regole da non rompere: i pulsanti di navigazione stanno fuori da ogni widget flessibile, quindi non si comprimono mai e l'unico elemento che cede spazio e' l'indicatore di pagina; l'indicatore e su due livelli perche' la larghezza la comanda solo il valore (`1/12`), e la didascalia puo' restare piccola gratis; il campo `Righe` ha una `width` esplicita perche' `DropdownMenu` ha un floor interno di 112px che `IntrinsicWidth` non scavalca, e dentro quella larghezza i vincoli (`contentPadding` e `suffixIconConstraints` via `decorationBuilder`) sono dichiarati a mano, altrimenti si eredita un padding e un tap target che cambiano fra Android e desktop. I valori nel file sono calcolati sui glifi del Roboto: se si aggiunge un controllo, il conto va rifatto e documentato li'
- Il controller di paginazione espone `progressCaption` e `progressValue` invece di una stringa unica `progressLabel`: la barra li mette su due righe e serve tenerli separati. `GlobalPaginationOptions.infiniteLabel` resta la parola perche' e' il valore interno che viaggia fra controller e barra, mentre `infiniteDisplayLabel` e' il simbolo mostrato: il campo e' dimensionato sul testo, e con `Infinito` la larghezza dipenderebbe da quale voce e' selezionata
- Le sole azioni stock-changing del modulo sono il carico confermato, la rettifica confermata, lo spostamento confermato e l'annullamento, che registra una rettifica o uno spostamento al contrario. Fornitori, riordino, ordini fornitore, bozze ricezione e conteggio restano stock-neutral. Il ledger in se e in quanto lettura e stock-neutral: l'annullamento scrive, ma con un movimento nuovo, non modificando quello che annulla
- `QueryMgwsLoyalty` usa rotte registrate per stato, cliente, lookup carta/email, carta, punti, storico e statistiche
- Se `PlatformManager.isMgwsAvailable` è `false`, ogni flusso MGWS deve terminare prima della chiamata REST con il valore sicuro del proprio contratto: `false`, `null`, raccolta vuota o feedback operativo
- La cancellazione carta loyalty non cancella cliente o storico; se la carta non esiste, la rotta restituisce errore e non va trattata come successo idempotente
- Le rotte MGWS richiedono utente autenticato e capability route-specifiche; il codice client deve gestire `401`, `403`, `400`, `404`, `409` e `503` come risposte contrattuali possibili
- I permessi operativi si raggiungono solo dal dipendente: `PlatformManager.permessiUtente` non espone una lista utenti generica e va sempre chiamato con il `wp_user_id` di un dipendente. `QueryUserWordPress.getUtenti` e stato rimosso perche` puntava a `GET /wp-json/mgws/v1/users`, rotta che il plugin non registra
- Le rotte credenziali (`app-passwords`, `woo-keys`) hanno un allow piu restrittivo rispetto a quelle dei permessi: `mgws_manage_credentials` e solo `administrator`. Per questo `QueryUserWordPress` solleva `PermessiUtenteException` con lo status HTTP invece di un `Exception` generica, cosi la UI puo distinguere il 403 da un guasto e degradare la sola sezione credenziali senza far fallire il caricamento di ruoli e capability

## Persistenza

- `AppSettings` salva solo preferenze globali o condivise
- Segreti e token sensibili usano storage sicuro
- Le preferenze non sensibili possono essere sincronizzate su WordPress tramite MGWS; se MGWS non e disponibile, la cache locale resta il fallback operativo
- Le impostazioni coprono immagini, IA, shortcut, pagina default e backend WordPress
- Le impostazioni specifiche di una pagina o modulo stanno nella sua settings view dedicata

## WooCommerce tax rates

- `WooQueryTasse.getTaxRates` espone `country` e `state` come filtro reale lato app: WooCommerce non supporta questi filtri sul relativo endpoint REST, quindi il metodo pagina tutte le tax rates, filtra localmente e poi applica la pagina richiesta.

## Moduli chiave

- `inventory/inventory_global.dart` per lettura e confronto dello stock WooCommerce/MGWS
- `inventory/inventory_module.code.dart` per l'enum dei moduli e le sue regole, `inventory/inventory_movement_groups.code.dart` per il raggruppamento del ledger per operazione e i contromovimenti, `inventory/inventory_product_section.gui.dart` per la sezione prodotti condivisa dai pannelli, `inventory/inventory_movements.gui.dart` e `inventory/inventory_movements_detail.gui.dart` per il ledger e la scheda del movimento
- `prodotti/prodotti_gestisci/` pubblica ogni pagina WooCommerce appena caricata tramite il controller, mantenendo il download delle pagine successive in background; la UI sincronizza la paginazione locale a ogni avanzamento senza overlay bloccante. Quando un prodotto variabile viene selezionato, `ProdottiGestioneController` carica tutte le pagine varianti WooCommerce tramite un loader iniettabile e passa gli attributi del prodotto alla conversione delle varianti. La modifica rapida usa gli stati WooCommerce `publish`, `private`, `draft` e `pending`, etichettando `pending` come `In revisione`.
- `prodotti/prodotti_crea/` usa uno stepper con `Informazioni Base`, `Prezzi e Stock`, `Immagini`, `Dettagli` e `Varianti`. Il `Tipo prodotto` e nullable in creazione e blocca gli altri controlli finche non viene selezionato; in modifica l'editor riceve solo `prodottoIdDaModificare` e `codiceProdotto`, ricarica dal server il `ProdottoGlobal` fresco e usa `codiceProdotto` come fallback se l'ID non e risolvibile. Il tipo resta `variabile` quando il prodotto Woo e variabile anche se la ricarica varianti e vuota. L'editor passa gli attributi del prodotto al caricamento delle varianti e non sovrascrive varianti con attributi validi con una ricarica degradata; i barcode top-level vengono compilati solo per prodotti semplici e sono forzati vuoti nel payload dei prodotti variabili. Il payload WooCommerce usa un unico builder prodotto, ma in update non include gli attributi variabili del padre per evitare di riscrivere gli attributi globali WooCommerce delle varianti; in create li include. Prima dell'update il recap mostra solo i nuovi valori dei campi modificati e i campi mancanti, e usa testo selezionabile con copia negli appunti; la conferma resta bloccata se ci sono errori obbligatori. Dopo il salvataggio l'editor marca sporca la cache prodotti e rimuove la cache varianti del prodotto salvato. La scheda `Immagini` mantiene `immagineUrl` come principale e `immaginiAggiuntive` come gallery ordinata; il selector media multi-selezione restituisce piu `MediaFile` e conserva localmente i metadati disponibili per nome, dimensione e badge pixel non bloccanti. Le varianti riusano lo stesso selector multi-selezione: la prima foto diventa `image`, le successive vengono salvate in `gallery_image_ids` quando esiste l'ID media WordPress, e il meta legacy `immagini_variante` resta come fallback compatibile per URL non risolvibili a ID. La sezione attributi della variante e in sola lettura con chiavi stabili per evitare stati errati dei campi dopo l'espansione della riga.
- Il mapping WooCommerce → modello globale usa `prezzoNormale = regular_price ?? price` come fallback iniziale, ma per i prodotti variabili il prezzo autorevole della griglia arriva dalle varianti: su `wc/v3` il prodotto padre può esporre solo il prezzo attivo e lasciare vuoti `regular_price`/`sale_price`.
- In griglia, quando le varianti sono caricate: se tutte condividono lo stesso prezzo o sconto la label mostra il valore unico; se i prezzi o gli sconti differiscono mostra `Prezzi variabili`. La cache pricing della `DataGridViewCache` va invalidata a ogni aggiornamento varianti prima del ricalcolo. Il calcolo del pricing consulta prima le varianti agganciate all'istanza prodotto e poi la cache varianti condivisa: in questo modo resta corretto anche quando le istanze vengono ricreate dal caricamento WooCommerce (che le produce senza `varianti` agganciate) e il prefetch successivo salta i prodotti già in cache.
- `dashboard/` per analisi WooCommerce, grafici, widget configurabili e generazione PDF/CSV dal periodo corrente; `dashboard.gui.dart` ospita la pagina, `dashboard_report_panel.gui.dart` ospita il pannello analisi/export, `dashboard.code.dart` contiene modelli, filtro periodo, capability e gateway report, `dashboard_report_export.dart` contiene scelte e servizi di export
- `cassa/` per vendita e checkout
- `report/class_report.dart` per etichette e QR

## Build e distribuzione

- La configurazione di build e distribuzione non fa parte del contratto backend MGWS v1 descritto in questa guida
- Le modifiche al contratto MGWS devono restare separate da pipeline, pacchetti pubblici e canali di distribuzione
- Per sviluppare o verificare il backend MGWS, usa le sezioni su connettori, capability, rotte e test di contratto
- In VS Code, la configurazione di avvio `4. Flutter Android Virtual (locale)` avvia l'AVD locale `pixel_36` tramite `script/start_android_emulator.sh`, attende che Android e ADB siano pronti e poi avvia il debugger Flutter sul device `emulator-5554`. Il debugger compila l'APK debug corrente e lo installa sull'emulatore a ogni nuova sessione; hot reload e hot restart aggiornano l'app senza ricompilazione completa. Il task inoltra inoltre le porte host 8080 e 8081 con ADB: nell'emulatore `http://localhost:8080` e `http://localhost:8081` raggiungono i rispettivi servizi gia in ascolto sul PC. L'Android Emulator usa una rete NAT e non ottiene un IP bridged della LAN; per i servizi locali usa gli inoltri ADB.
- Per le prove locali da codice esiste `script/run_debug.sh -d <device>`: a ogni avvio incrementa il contatore gitignorato `.debug_build_nr` e lo passa via `--dart-define=DEBUG_BUILD_NR`. L'app mostra `Versione X (debug #N)` solo nelle build debug; le release CI/GitHub non passano il define e non mostrano mai il suffisso, quindi la versione di distribuzione resta quella del pubspec/pipeline.

## Regole pratiche

- Se il comportamento e ecommerce standard, il riferimento diretto e WooCommerce
- Se il comportamento e gestionale, di audit, POS o loyalty, il riferimento e MGWS
- Se il dato e temporaneo o di sola interfaccia, resta nella pagina Flutter
- Se il dato e persistente e condiviso da piu utenti o dispositivi, deve avere una strategia lato WordPress/MGWS
- Nella dashboard il filtro di analisi attivo e oggi solo il periodo; brand, varianti, attributi e filtri avanzati non devono essere mostrati come controlli effettivi finche il layer dati non aggrega davvero quelle dimensioni.
- Nomenclatura codici prodotto: `codiceProdotto` e `variante.codiceProdotto` corrispondono a `sku` WooCommerce; `barcodeInterno` corrisponde a `global_unique_id`; `barcodeProduttore` (prodotto) e `barcodeFornitore` (variante) corrispondono a `barcode_manufacturer`. SKU e barcode non sono intercambiabili e non devono avere fallback fra loro. Il filtro `Barcode` ricerca in OR barcode interno ed esterno, mantenendo i valori separati nel modello. Le chiavi tecniche restano invariate: MGWS `supplier_sku`, chiavi SharedPreferences/storico (`productSku`, `variationSku`), contenuto QR `SKU:`; il campo della libreria `woocommerce_flutter_api` resta `WooProduct.sku`.

## Regola pratica

Tieni separati UI, logica di dominio e integrazione backend. Se una funzione dipende da un plugin esterno non nativo, passa prima da MGWS.
