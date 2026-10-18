# Architettura

## Strati

- UI Flutter
- Logica di schermata
- Servizi di dominio
- Connettori backend

## Struttura cartelle

- Ogni pagina o modulo principale vive in una cartella dedicata sotto `lib/`
- Ogni modulo separa UI e logica con due file gemelli:
  - `nome_modulo.gui.dart` per widget, layout e interazione utente
  - `nome_modulo.code.dart` per stato, orchestrazione e logica schermata
- `lib/reuse_class/` contiene componenti e pezzi di codice riusabili in piu pagine
- Ogni classe o componente riusabile importante vive nella propria cartella sotto `lib/reuse_class/`
- `lib/reuse_class/barcode/` centralizza il modulo barcode condiviso: lo scanner usato dalle schermate, che chiamano una sola funzione e ricevono il codice letto come `String?` senza duplicare UI o lettura fotocamera, e il generatore di codici interni `BarcodeGenerator.generaCode128(esclusi: ...)`
- `lib/reuse_class/datagridview/` contiene la griglia tabellare condivisa da tutte le tabelle operative del progetto, inclusa l'inventario
- `lib/reuse_class/device_utils/` contiene `DeviceUtils`, che classifica il dispositivo in smartphone, tablet o desktop e distingue le piattaforme mobili da quelle desktop
- `inventory/inventory_quick_load_catalog.code.dart` espone il catalogo prodotti usato anche dal pannello inventario per risolvere barcode e costruire righe di carico
- `login/jwt_api/` e il layer di integrazione con le piattaforme esterne
- `settings/` e il contenitore delle visualizzazioni di configurazione dell'app

## Settings

- `settings.gui.dart` e la pagina madre che mostra tutte le visualizzazioni settings
- Ogni pagina o modulo che ha configurazioni proprie deve avere una visualizzazione settings separata
- Le impostazioni di una pagina non devono essere mischiate in un calderone globale se riguardano solo quella pagina
- `AppSettings` contiene solo impostazioni realmente globali o usate da classi globali
- Le impostazioni globali devono restare separate dalle impostazioni specifiche dei moduli
- Se un modulo ha configurazioni proprie, la sua settings view deve essere riconoscibile e vicina al modulo stesso
- La struttura delle settings segue la struttura dei moduli: se esiste un modulo in `lib/`, la sua configurazione deve avere una visualizzazione dedicata in `lib/settings/`
- Le settings globali servono solo per classi o comportamenti veramente condivisi da tutta l'app

## Nodi principali

- `main.dart` avvia tema e app
- `home/` controlla navigazione e docking
- `login/` gestisce autenticazione e connettori
- `settings/` conserva preferenze globali e ospita le view delle impostazioni per modulo
- `inventory/` gestisce il magazzino con MGWS come sorgente autorevole dello stock gestionale e del ledger dei movimenti. `inventory.gui.dart` e solo la cornice: possiede il selettore dei moduli, il campo `Dettagli` condiviso e la transizione fra moduli, mentre i pannelli operativi stanno in file propri. `inventory_module.code.dart` tiene l'enum dei moduli e le sue regole (quali scrivono stock, quali si possono riaprire dal ledger) senza dipendere dal widget, e `inventory_movement_groups.code.dart` legge il ledger per operazione invece che per prodotto e costruisce i contromovimenti di annullamento. I pannelli legacy di fornitori, riordino, ordini fornitore e ricezioni esistono ancora nel codice ma non sono raggiungibili dal selettore dei moduli
- `cassa/` delega il checkout POS a MGWS, che crea l'ordine WooCommerce e registra audit e movimenti; la voce `Storico cassa` conserva lo storico scontrini POS locale (canale `pos`, SharedPreferences/JSON) separato dagli ordini Woo, con resi vincolati alla riga venduta, turno cassa esplicito locale e chiusura del turno
- `dashboard/` produce dati e grafici

## Contratto MGWS

- `login/jwt_api/query_mgws/` contiene i client MGWS usati dall'app
- `WooConnect` e' l'unico owner dei connettori di autenticazione e l'unica fonte di `siteUrl` e del Dio autenticato: i client MGWS non istanziano connettori propri, altrimenti le richieste viaggerebbero con credenziali diverse da quelle della sessione attiva e MGWS risulterebbe irraggiungibile
- `QueryMgwsPos` copre il checkout POS v1 con idempotenza basata su `idempotency_key` o meta `_id_scontrino_locale`
- `QueryMgwsPrint` legge e scrive la libreria di stampa (modelli, categorie, formati carta) condivisa dal sito; la sezione `Template e stampa` dichiara `requiresMgws` e non si apre senza MGWS, perche quei dati esistono solo sul server
- `QueryMgwsInventory` copre letture stock, statistiche, soglie basse, sync Woo verso MGWS, reconcile stock, RFID scan resolve-only, carico rapido, fornitori, riordino, ordini fornitore, ricezioni, movimenti e conte fisiche
- `QueryMgwsLoyalty` copre stato servizio, cliente, lookup, carta, punti, storico e statistiche
- I permessi operativi WordPress/MGWS si gestiscono dall'anagrafica `Dipendenti`: l'app legge o modifica ruoli/capability solo per dipendenti MGWS collegati a un `wp_user_id`, evitando una gestione generica di capability su utenti WordPress non dipendenti
- MGWS conserva `mg_stock_levels` come sorgente stock, `mg_stock_moves` come audit movimenti, gli ordini fornitore e le ricezioni come documenti operativi, le sessioni di conta come prove fisiche e l'ordine WooCommerce come record checkout collegato
- Le tabelle loyalty MGWS conservano conto, carta nullable, saldo e ledger movimenti; la cancellazione carta non cancella storico o conto

## Login e sicurezza

- Il login e la parte piu sensibile dell'app
- Ogni modifica al login richiede prima una verifica dei rischi di sicurezza
- Non sono ammessi fallback insicuri o scorciatoie temporanee
- I vari metodi di login devono restare progettati per essere sicuri per default
- Le credenziali sensibili non vanno in chiaro
- `login/jwt_api/` deve restare il layer di astrazione tra app e piattaforme esterne
- Oggi il layer parla con WooCommerce e WordPress, ma deve poter ospitare in futuro altre piattaforme senza cambiare la logica di alto livello dell'app
- Ogni metodo di login deve essere convalidato prima della modifica, sia per sicurezza sia per coerenza del flusso

## Privacy e DeGoogled

- L'app deve essere privacy-first
- Non deve richiedere servizi Google come dipendenza architetturale base
- Google puo essere usato solo se scelto esplicitamente dall'utente o come opzione non obbligatoria
- Niente tracking nascosto, telemetria, ads o raccolta dati non necessaria
- Preferire soluzioni locali, self-hosted, MGWS/WordPress e standard aperti
- I dati sensibili devono restare locali quando possibile oppure su WordPress/MGWS con storage sicuro
- Ogni integrazione esterna deve essere valutata anche per privacy, dipendenze Google, necessita reale e minimizzazione dati
- Se una feature puo funzionare senza Google, deve poter funzionare senza Google
- Se una feature usa Google, deve essere opzionale e dichiarata chiaramente
- Nessun componente deve introdurre tracking o servizi Google di nascosto

## Principi

- UI e backend restano separati
- Le dipendenze da plugin esterni passano da MGWS
- Le credenziali sensibili non vanno in chiaro
- WooCommerce resta il motore e-commerce usato dal plugin, non orchestrato direttamente dalla cassa Flutter
- WooCommerce gestisce il dominio ecommerce nativo, MGWS gestisce la logica gestionale custom e il POS
- L'app Flutter parla direttamente solo con WooCommerce e MGWS per il perimetro WordPress
- Route MGWS mutate richiedono autenticazione e capability adeguate; l'app non deve aggirare i controlli lato plugin
- Se una scelta riguarda solo la UI o lo stato temporaneo, resta nella pagina Flutter
- Se una scelta riguarda un dato persistente e condiviso, deve passare da WordPress/MGWS
