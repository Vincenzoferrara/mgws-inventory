# Configurazione

## Sezioni principali

- `Generale` - impostazioni operative comuni, come la sede in uso
- `Inventario` - valori selezionabili e valori predefiniti delle ubicazioni proposte nel modulo `Aggiungi` (magazzino, stanza, scaffale, ripiano). Un livello con lista vuota viene nascosto e non inviato a MGWS
- `Prodotti` - regole su immagini, eliminazione e filtri
- `Cassa` - nome/numero cassa fisica e obbligatorieta del turno cassa
- `Tema` - look chiaro/scuro e colori; il colore primario scelto guida anche
  sfumature, pulsanti, chip e selezioni della `DataGridView`. L'opzione
  `Sfondo segue tema chiaro/scuro` decide se gli sfondi decorativi usano la
  variante chiara/scura del tema o il colore primario scelto
- `IA` - token e modelli supportati
- `RFID` - parametri lettori e scansione
- `Shortcut` - tasti rapidi personalizzati

## Regola settings

- Le impostazioni globali stanno in `AppSettings`
- Le impostazioni specifiche di una pagina stanno nella sua settings view dedicata
- La pagina `settings.gui.dart` mostra tutte le views di configurazione disponibili

## Preferenze utili

- Dimensione pagina predefinita
- Magazzini e stanze condivisi, scaffali e ripiani proposti per le singole righe nel modulo `Aggiungi`, con valori predefiniti opzionali. Lascia vuota la lista di un livello per disattivarlo e nasconderlo dal flusso
- Colonne visibili nella griglia prodotti
- Larghezza del pannello prodotti/dettaglio in `Prodotti`: preferenza locale della macchina, salvata fuori dalle impostazioni sincronizzate e non mostrata nella UI impostazioni
- Shortcut della pagina prodotti per attivare la modifica rapida, salvare, selezionare le righe visibili, eliminare e annullare/uscire
- Persistenza filtri nella pagina prodotti
- Modalita testo per i parametri attributo
- Avvisi dimensioni immagini prodotto: le soglie larghezza/altezza servono solo a mostrare un avviso informativo nella libreria media, senza modificare i file caricati
- Connessione RFID tramite USB o WiFi; Bluetooth non e disponibile finche il modulo RFID resta in alpha
- Sede in uso in `Impostazioni > Generale`: se vuota, lo storico POS non salva una sede sugli scontrini
- Nome/numero cassa in `Impostazioni > Cassa`: se vuoto, lo storico POS usa un nome neutro; la giornata operativa resta `giorno|cassa`
- `Turno cassa obbligatorio` in `Impostazioni > Cassa`: quando attivo, la cassa mostra apri/chiudi turno e richiede un turno aperto per aggiungere prodotti e completare il checkout; quando disattivo, il turno non viene usato nella schermata cassa e non blocca la vendita. La modifica e globale lato MGWS e richiede un utente con permessi di gestione WooCommerce/WordPress.
- Lingua interfaccia in `Impostazioni > Generale`: combobox con `Lingua di sistema` in cima, che mostra fra parentesi la lingua effettiva, poi le lingue supportate con nome nativo. Con `Lingua di sistema` l'app passa `null` a `MaterialApp.locale` e lascia risolvere a Flutter, con fallback su inglese
- Un cambio lingua deve raggiungere ogni stringa visibile senza riavvio. Un widget che resta montato dopo il cambio deve leggere le traduzioni nel proprio `build`: leggerle una volta e salvarle in un campo, o in una lista catturata da un widget inserito una sola volta nel docking layout, mantiene le stringhe della lingua precedente. Per questo la pagina iniziale della home riceve un builder di sezioni invece di una lista gia costruita, cosi la lettura di `Localizations` avviene durante il suo build e la pagina si ricostruisce con la lingua nuova
- I titoli delle schede sono l'eccezione, perche la libreria docking li legge da `DockingItem.name`, una stringa semplice, e non espone un builder per l'etichetta. `HomeLogic.aggiornaTitoli` risolve di nuovo il titolo di ogni scheda aperta e riscrive il nome sul mentre l'albero dei widget si ricostruisce, quindi la stessa ricostruzione rilegge le etichette nuove senza `setState`. Il suffisso dell'istanza (`#2`, `#3`) viene salvato una volta per scheda in `HomeTabMeta.istanza` e riapplicato a ogni aggiornamento, cosi chiudere una scheda non rinumera quelle rimaste aperte
- `Sfondo segue tema chiaro scuro` in `Impostazioni > Tema`: default `true`, quindi su una nuova installazione gli sfondi decorativi seguono il tema chiaro o scuro. Disattivandoli usano il colore primario scelto. Il default vale solo quando non c'e un valore salvato, percio una scelta gia fatta non viene sovrascritta

## Regola backend

- WooCommerce resta il canale diretto per le funzioni native WooCommerce
- MGWS gestisce checkout POS, stock gestionale, carico rapido, fornitori, riordino, ordini fornitore, ricezione/convalida, movimenti, inventario fisico e loyalty v1
- Per il perimetro WordPress, l'app deve configurare e usare solo provider diretti WooCommerce e MGWS
- Plugin terzi non vanno configurati come provider app; eventuali scelte interne al sito devono passare da MGWS
- Il checkout POS dovrebbe inviare `idempotency_key`; il meta `_id_scontrino_locale` resta fallback di compatibilita
- L'utente WordPress usato dalle chiamate MGWS deve essere autenticato e avere le capability richieste dalla rotta, per esempio lettura stock, movimento stock, accettazione ordine o gestione WooCommerce
- La sezione `Credenziali attive` della scheda dipendente richiede `mgws_manage_credentials`, che MGWS concede solo al ruolo `administrator`. Con altri ruoli la sezione resta visibile ma non operativa: ruoli e capability del dipendente continuano a essere gestibili
- `DELETE /employees/{id}` disattiva il dipendente ma non revoca le sue credenziali WordPress. Se serve revocare Application Password o chiavi WooCommerce, va fatto dalla sezione `Credenziali attive` del dipendente
- Le rotte inventario `stock/sync`, `stock/reconcile`, `quick-load`, fornitori, riordino, ordini fornitore, ricezioni, movimenti e conte fisiche sono operative e dipendono dalle capability MGWS/WooCommerce dell'utente configurato
- La rotta `rfid/scan` e operativa come resolve-only: risolve tag o barcode e non va configurata o presentata come incremento automatico stock
- Il modulo `Aggiungi` non richiede campi documento: bastano uno o piu prodotti semplici o varianti concrete, quantita positiva per ogni riga e conferma. Il motivo e' fisso (`Carico merce`); la nota e' il campo `Dettagli` della pagina
- Magazzino, stanza, scaffale e ripiano non sono obbligatori: l'app invia soltanto i valori compilati; senza ubicazione esplicita MGWS sceglie il primo magazzino valido nel perimetro autorizzato e lascia vuoti i dettagli fisici
- Il catalogo del modulo `Aggiungi` riusa il caricamento progressivo WooCommerce della gestione prodotti; ogni riga confermata genera una richiesta MGWS idempotente separata
- Il ledger dei movimenti non ha rotte di scrittura: le azioni che lo alimentano dal lato operatore sono l'annullamento, che registra un movimento nuovo invece di cancellare il vecchio, e la riapertura in un pannello, che non scrive finche' l'operatore non conferma. Non va quindi configurata nessuna capacita di "cancella movimento"
- Fornitori, riordino e ordini fornitore non vanno configurati come carichi diretti: preparano dati e documenti, ma lo stock cambia solo con ricezione convalidata
- Le conte fisiche cambiano stock solo dopo approvazione/post della sessione
