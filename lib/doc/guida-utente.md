# Guida Utente

## A cosa serve

L'app gestisce le attivita quotidiane di un negozio di abbigliamento: cassa, prodotti, ordini, clienti, carte fedelta, report e configurazione.

## Accesso

1. Inserisci l'URL del sito
2. Scegli il metodo di login
3. Usa JWT, WooCommerce API o WordPress Admin (credenziali wp-admin)
4. Se lavori in locale o rete locale (localhost, 192.168.x.x, 10.x.x.x), attiva l'opzione per lo sviluppo locale: vale anche per WordPress Admin su HTTP

Su smartphone e schermi stretti il login si apre come schermata a pagina intera, cosi i campi usano tutta la larghezza disponibile. Su schermi grandi resta in una finestra di dialogo sopra l'area principale.
La barra in alto mostra a destra il pulsante `Visualizza Log` e lo stato login: se non sei autenticato compare `Accedi`, altrimenti avatar e nome dell'utente WordPress con stato `Online` e menu con `Logout`.

## Visualizza Log

La schermata `Visualizza Log` mostra i messaggi diagnostici temporanei dell'app. Di base i log restano in memoria e non vengono salvati in cartelle utente come Download o Documenti.

- `Registra log temporaneo` avvia la scrittura in un file temporaneo interno all'app, utile quando devi riprodurre un problema e poi condividere il risultato.
- `Ferma log temporaneo` interrompe la scrittura su file, lasciando consultabile il buffer memoria.
- `Condividi e pulisci` crea uno snapshot temporaneo del contenuto filtrato, lo passa al sistema di condivisione e poi svuota memoria e file temporanei.
- `Cancella log` elimina il buffer memoria e i file temporanei senza condividerli.
- Il filtro per livello permette di vedere tutti i messaggi oppure solo debug, warning o errori.
- Il test diagnostico WooCommerce usa gli stessi log temporanei mostrati nella schermata.

## Aree principali

- `Cassa` - vendita POS e chiusura ordine; il turno cassa esplicito si usa solo quando e attivato in `Impostazioni > Cassa`. La voce `Storico cassa` mostra lo storico scontrini POS separato dagli ordini WooCommerce, con resi vincolati alla riga venduta e chiusura turno quando il turno e in uso; l'operatore e l'utente loggato
- `Prodotti` - catalogo e inventario
- `Inventario MGWS` - carico, rettifica, spostamento tra ubicazioni e lettura del ledger dei movimenti
- `Nuovo Prodotto` - inserimento articoli
- `Coupon` - sconti e promozioni
- `Ordini` - gestione ordini
- `Clienti` - anagrafiche clienti
- `Carte Fedelta` - punti e fidelizzazione
- `Report` - etichette e stampe
- `Dashboard` - analisi vendite, prodotti, ordini, stock e generazione report PDF/CSV
- `Impostazioni` - preferenze dell'app, inclusa la sede in uso nella tab `Generale`
- `Aggiornamenti` - controllo e installazione aggiornamenti desktop
- `Dipendenti` - anagrafiche del personale, collegamento all'utente WordPress e gestione dei permessi MGWS quando il collegamento e presente

## Clienti e Dipendenti

- `Clienti` mostra e modifica i clienti WooCommerce. Non contiene ruoli o capability operative.
- `Dipendenti` mostra le persone interne gestite da MGWS. Nel form puoi indicare l'`ID utente WordPress` se il dipendente ha un account sul sito.
- Nel dettaglio dipendente, la sezione `Accesso e permessi` mostra ruoli e capability solo quando il dipendente e collegato a un utente WordPress. Se non e collegato, i permessi non sono modificabili da quella scheda.
- Le capability operative MGWS modificabili dalla scheda dipendente sono limitate alla whitelist esposta dall'app e validate dal backend.
- Nella stessa scheda trovi `Credenziali attive`, dove puoi revocare le Application Password e le chiavi WooCommerce del dipendente. L'app non le genera: quando accedi con WordPress Admin crea da sola l'Application Password del dispositivo, quindi da qui si revoca e basta. La sezione funziona solo se accedi con un account amministratore del sito; con altri ruoli vedi l'avviso che serve un amministratore, mentre ruoli e capability restano gestibili.

## Scansione barcode e QR

Le azioni di scansione barcode o QR aprono lo scanner condiviso a schermo intero su smartphone e tablet. La schermata mostra l'inquadratura della fotocamera, l'area di scansione, il pulsante di chiusura e il controllo torcia quando disponibile; il codice rilevato viene restituito al flusso da cui e stata avviata la scansione.

Nella `Cassa`, il lato sinistro contiene il campo barcode, il pulsante scanner e il pulsante `Aggiungi manualmente`. Inserendo o scansionando un barcode, la cassa cerca il prodotto o la variante e lo aggiunge direttamente al carrello; se il barcode non esiste viene mostrato un errore, mentre un prodotto o una variante senza quantita disponibile viene bloccato. Sotto i comandi e visibile il carrello come lista righe scontrino, con gli stessi controlli per quantita, rimozione e sconto riga. Su desktop il lato destro resta dedicato a tipo operazione, cliente, carta fedelta, coupon, sospensione, totali e pagamento. Su smartphone il carrello occupa il centro della schermata, il totale con `Paga` resta fisso in basso e il pulsante opzioni apre tipo operazione, cliente, carta fedelta, coupon e scontrini sospesi in un pannello dedicato.

## Prodotti

La schermata `Prodotti` e una postazione operativa per consultare e gestire il catalogo.

- Il pannello `Filtro` in alto, richiudibile con la freccia a destra del titolo, permette di cercare, scegliere campo e operatore del filtro, inserire il valore, aggiungere filtri, nascondere gli esauriti, ordinare la lista e aggiornare la lista. I filtri `Codice articolo / SKU`, `Nome prodotto` e `Barcode` sono distinti; `Barcode` trova sia il barcode interno sia quello del produttore, su prodotto semplice o variante. Chiuso occupa una sola riga: i controlli compaiono solo quando lo apri, cosi la griglia resta grande anche da chiuso.
- Il comando `Scegli colonne` sta accanto al pannello `Filtro`, quindi resta sempre raggiungibile anche a pannello chiuso: apre l'elenco delle colonne visibili con ricerca e anteprima delle voci disponibili.
- I filtri attivi compaiono come chip rimovibili sotto il pannello, insieme al chip `Esauriti nascosti` quando i prodotti senza disponibilita sono nascosti, e `Cancella tutti` azzera ogni filtro in un colpo.
- La selezione per le azioni di massa si fa dalle checkbox della griglia, oppure dalla casella di intestazione per selezionare o deselezionare tutta la pagina corrente; il conteggio delle righe selezionate compare come `Sel:` nella barra di paginazione.
- La `DataGridView` prodotti mostra anteprima, dati principali, prezzo, disponibilita, quantita, varianti, stato WooCommerce e marca in base alle colonne visibili anche su Android e schermi stretti; per i prodotti variabili i prezzi vengono aggiornati appena sono caricate le varianti: se tutte hanno lo stesso prezzo o sconto viene mostrato il valore unico, altrimenti compare `Prezzi variabili`. Passando il mouse sull'anteprima compare una vista rapida fissa di 300 px, mantenuta entro la finestra e senza ritagliare la foto. Gli stati sono mostrati come `Pubblico`, `Privato`, `Bozza` e `In revisione`. La tabella occupa tutta la larghezza della sezione, senza riquadri annidati: la colonna `Nome` e' l'unica a larghezza variabile e incassa la larghezza residua, quindi il nome non viene troncato mentre resta spazio libero, e su schermi stretti le colonne in eccesso si raggiungono scorrendo in orizzontale. Il nome occupa al massimo due righe e non ripete sotto di se il codice articolo, gia' presente nella colonna `Cod. art.`
- La prima pagina di prodotti compare appena disponibile; le pagine successive continuano a caricarsi in background e una barra sottile indica l'aggiornamento in corso senza coprire la griglia.
- La barra di paginazione resta su una riga sola e centra il gruppo dei controlli nella sezione: prima pagina, pagina precedente, selettore `Righe`, indicatore di pagina, pagina successiva, ultima pagina. L'indicatore e su due livelli, con `Pag.` sopra e `pagina/totale` sotto (`1/12`); in caricamento infinito diventa `Caricati` sopra e le righe caricate sotto, e le quattro frecce scompaiono perche' non hanno una pagina da raggiungere. La voce `Infinito` del selettore righe e' mostrata come `∞`. Da 600px in su la barra aggiunge le pillole `Tot:` e `Sel:` nello stesso gruppo centrato; sotto quella larghezza le omette per lasciare spazio ai controlli, che hanno sempre la loro dimensione piena.
- Su desktop la schermata e divisa in elenco prodotti a sinistra e dettaglio a destra, separati da una linea verticale trascinabile senza spazio vuoto tra griglia e pannello dettaglio. La larghezza scelta resta salvata sulla macchina in uso; su schermi piccoli il dettaglio si apre in una pagina dedicata.
- Le checkbox selezionano piu prodotti per le azioni di massa senza cambiare il dettaglio aperto; il click o tap sulla riga prodotto aggiorna invece il dettaglio.
- Il click destro su una riga apre il menu azioni con `Modifica`, `Elimina` e `Crea`; il menu e gestito dalla `DataGridView` condivisa delle tabelle del progetto.
- Il pannello dettaglio mostra immagine, galleria, dati prodotto, modifica rapida, filtri varianti e lista varianti; il visualizzatore e le miniature mantengono le proporzioni originali della foto. La galleria ha una barra orizzontale per raggiungere tutte le foto; il pulsante `Apri` mostra la foto selezionata a piena dimensione e permette di passare alla precedente o successiva con le frecce laterali. Su schermi stretti il visualizzatore immagini si apre a schermo intero con area sicura e controlli compatti. Il contenitore dei filtri varianti usa lo stesso sfondo neutro delle altre schede, mentre la lista varianti e compatta e separa le righe con sfondi e bordi leggeri per evitare riquadri annidati troppo marcati. Nome, barcode, attributi, prezzo e quantita delle varianti nel dettaglio sono selezionabili per copia e incolla. Quando selezioni un prodotto variabile l'app carica tutte le pagine WooCommerce delle varianti e l'eventuale foto dedicata resta visibile direttamente nella riga della variante. Le varianti scontate mostrano il prezzo scontato in evidenza e il prezzo normale barrato.
- `Modifica rapida` consente di aggiornare categorie, tag, stato e, per singolo prodotto, prezzo e quantita delle varianti; in selezione multipla sono disponibili categorie, tag, stato ed eliminazione secondo le impostazioni. Prima di applicare una modifica o un'eliminazione, un riepilogo mostra gli elementi e le modifiche coinvolte. Gli stati selezionabili sono `Pubblico`, `Privato`, `Bozza` e `In revisione`.
- Le shortcut configurate in `Impostazioni > Shortcut` sono operative nella griglia e nel dettaglio: modifica rapida, salvataggio, selezione visibile, eliminazione e annullamento/uscita.
- In creazione o modifica prodotto, `Tipo prodotto` va selezionato prima degli altri campi: finche resta vuoto gli altri controlli restano bloccati. Quando apri `Modifica` da `Prodotti`, l'editor usa ID prodotto e codice prodotto per ricaricare dal sito l'ultima versione disponibile prima di compilare il form. Prima di aggiornare un prodotto esistente, il riepilogo mostra solo i nuovi valori dei campi realmente modificati e segnala i campi mancanti; il testo del recap e selezionabile e il pulsante `Copia` copia tutto il riepilogo negli appunti. Se manca un campo bloccante, puoi solo correggere. La scheda `Informazioni Base` contiene nome, codice prodotto, categorie, tag, descrizioni, marchio e stato WooCommerce; i campi barcode del prodotto sono visibili solo per prodotti semplici, mentre nei prodotti con varianti i barcode si compilano sulle singole varianti.
- In creazione o modifica prodotto, la sezione `Inventario MGWS` permette di abilitare una rettifica auditata dopo il salvataggio: inserisci lo stock MGWS totale finale e un motivo obbligatorio; l'app registra il valore con `Reconcile stock` solo se il prodotto e stato salvato con un `product_id` valido.
- La scheda `Immagini` dell'editor prodotto mostra un datagrid a tutta larghezza con checkbox, anteprima, uso, nome, verifica dimensioni e azioni. Ogni immagine puo essere aperta in anteprima grande; una sola immagine puo essere `Copertina`, mentre le altre immagini possono essere promosse a copertina, spostate su/giu, copiate negli appunti o rimosse. La colonna `Uso` mostra `Copertina` solo per la copertina prodotto e indica anche se e in quali varianti la foto viene usata, distinguendo `Copertina variante` dalle altre foto variante; se l'immagine e associata a piu varianti il tooltip mostra l'elenco completo. La barra superiore mostra solo totale foto e totale selezionate; puoi selezionare righe sia con checkbox sia cliccando sulla riga, poi usare le azioni massive come eliminazione, deselezione e promozione a copertina quando e selezionata una sola immagine non copertina. La verifica dimensioni mostra una label con pallino colorato (`Conforme`, `Fuori specifica`, `Nessuna specifica`, `Verifica in corso` o `Non verificabile`) in base alle soglie di `Impostazioni > Immagini`; non mostra i pixel numerici e non blocca il salvataggio. Il selettore media supporta checkbox, multi-selezione e Ctrl/Cmd+click.
- Nella modifica di un prodotto le immagini già presenti vengono mantenute senza essere ricaricate; puoi quindi aggiornare i dati del catalogo anche quando WordPress non può raggiungere gli URL locali delle proprie immagini.
- Nel passo varianti dell'editor prodotto, le combinazioni con attributi vengono visualizzate in una griglia gerarchica: la prima colonna unisce le righe dello stesso attributo principale (con precedenza a `Colore`), la seconda quelle del sottogruppo (con precedenza a `Taglia`) e ogni riga conserva immagine, barcode interno, barcode fornitore, prezzo, sconto e quantita. Apri una riga per modificare i dettagli completi della variante; ogni variante puo avere piu foto affiancate, la prima foto resta la principale della variante e le successive vengono salvate nella galleria variante nativa WooCommerce quando sono media WordPress con ID. Se le varianti non hanno attributi, l'editor le mostra come righe non raggruppate e segnala il motivo.
- In creazione o modifica prodotto, il campo `Barcode` ha accanto il pulsante con la bacchetta magica `Genera barcode automaticamente`: genera un valore numerico di 30 cifre compatibile Code128 (13 cifre casuali + data/ora attuale con millisecondi, es. `1234567890123` + `25042001` + `101010` + `123`). La data/ora incorporata rende il codice praticamente univoco anche tra generazioni ravvicinate; il generatore evita comunque di ripetere i barcode gia presenti nel modulo e sovrascrive il valore corrente del campo. Il pulsante e disponibile anche nel campo `Barcode` dei dettagli variante e nel form `Inserimento rapido variante`.

## Inventario MGWS

La schermata `Inventario MGWS` e la postazione operativa per lo stock gestionale. MGWS resta la sorgente autorevole di stock e del ledger dei movimenti; l'app mostra e invia solo dati MGWS o WooCommerce, senza chiamare plugin WordPress terzi. Un selettore in alto sceglie il modulo di lavoro: `Aggiungi`, `Rettifica`, `Sposta` o `Movimenti`. Le operazioni non sono mai visibili insieme, e ogni modulo scrive il proprio magazzino senza toccare gli altri.

- Sotto il selettore c'e' un solo campo `Dettagli`, valido per il modulo attivo. Non e' obbligatorio, ma quando lo scrivi viaggia con il movimento. Non compare in `Movimenti`, perche' li' non si registra niente: un campo che raccoglie testo e poi lo perde sarebbe peggio di non averlo.
- I tre moduli operativi condividono la stessa sezione prodotti: un campo barcode con lettore, il pulsante `Aggiungi prodotto esistente` che apre il catalogo WooCommerce (foto di copertina, ricerca per nome, barcode interno o barcode produttore, varianti concrete per i prodotti variabili) e la spunta del modo rapido. Con la spunta attiva il prodotto entra con la quantita minima e senza domande; togliendola l'app chiede la quantita riga per riga. Il campo barcode si svuota da solo quando il prodotto e' entrato, cosi' lo stesso codice non viene riletto e i pezzi non vengono raddoppiati.
- `Aggiungi` carica pezzi nel magazzino, singoli, associati a un ordine o identificati dal barcode. Il motivo e' sempre `Carico merce`. Se scegli la modalita ordine puoi valorizzare fornitore, documento e convalida; non sono richiesti per caricare. Le righe partono in sequenza e sono idempotenti: se una fallisce, quelle riuscite restano registrate e l'app conserva solo le righe fallite per un nuovo tentativo.
- `Rettifica` porta la quantita reale al valore che hai contato. Le due radio `Incremento` e `Diminuzione` stanno in testa alla sezione, accanto alla spunta, e rispondono alla domanda che ti fai mentre scansioni: quando leggo un barcode, aumento o diminuisco? Le vedi quindi anche a lista vuota, prima che la domanda si ponga da sola. Ogni riga ha il contatore dei pezzi e un `Azzera` che lascia il prodotto in lista senza correzione. Togliendo la spunta, ogni riga chiede invece il conteggio reale assoluto: e' il valore che hai in mano, non una variazione. Il motivo e' obbligatorio in entrambi i modi, e l'anteprima di ogni riga mostra `prima -> dopo` con il delta, cosi' un segno sbagliato si vede prima dell'invio. Le righe partono una alla volta e l'app non si ferma al primo errore: alla fine ti dice quante sono passate e quali no.
- `Sposta` trasferisce pezzi fra ubicazioni senza cambiare il totale del prodotto. Ogni riga sceglie il magazzino di partenza fra quelli dove il prodotto e davvero presente, con i pezzi disponibili accanto, e chiede la sede di arrivo. Magazzino di arrivo, stanza, scaffale e ripiano sono facoltativi: se non li indichi non vengono inviati, e MGWS li lascia vuoti invece di inventarli. Il pulsante `Dove si trova` mostra la tabella delle ubicazioni attuali del prodotto. Il motivo e' obbligatorio.
- `Movimenti` legge il ledger MGWS, una riga per operazione e non per prodotto: MGWS scrive una riga per ogni prodotto toccato, quindi l'app accorpa le righe che appartengono allo stesso movimento. Ogni riga mostra data, tipo di operazione, operatore, pezzi netti, quanti prodotti ha toccato, ultima modifica e motivo con i dettagli. Su uno spostamento i pezzi netti sarebbero zero, perche' la merce cambia magazzino senza cambiare numero: li vedi come pezzi spostati, con la rotta `da -> a` accanto. Doppio clic, o l'azione di contesto, apre la scheda del movimento con lo stock di ogni prodotto prima e dopo, o con i pezzi e la rotta se e' uno spostamento.
- Nella scheda di un movimento, `Modifica` riapre l'operazione nel modulo che l'ha prodotta, con i prodotti gia in lista e il suo dettaglio. E' disponibile per `Rettifica` e per `Sposta`: la rettifica riparte dal valore che il movimento aveva lasciato, lo spostamento riparte dagli stessi due magazzini e dagli stessi pezzi. Se nel frattempo il magazzino di partenza non ha piu' pezzi, la riga resta in lista ma ti avvisa e ti lascia scegliere un'altra partenza. Non e' disponibile per un carico: quella rotta sa solo aumentare lo stock, quindi ridurlo registrerebbe una diminuzione spacciata per carico. Negli altri casi il pulsante resta spento e la scheda spiega perche'.
- Nella scheda di un movimento, `Annulla movimento` riporta ogni prodotto allo stock che aveva prima di quel movimento. Il ledger non si modifica e non si cancella: l'annullamento registra un movimento nuovo, con il numero dell'originale nel motivo, quindi lo storico mostra sia il fatto sia il suo annullamento. Prima di partire controlla che lo stock di ogni prodotto sia ancora quello che il movimento aveva lasciato: se nel frattempo qualcun altro ha mosso quella merce, quella riga viene bloccata e ti viene detto quale, invece di azzerare anche l'altra operazione.
- Sullo spostamento l'annullamento funziona diversamente, e per forza: non si puo' togliere pezzi dallo scaffale che li ha solo spostati in un altro magazzino. Quindi l'azione registra uno spostamento al contrario, che riporta gli stessi pezzi dal magazzino di arrivo a quello di partenza, e il dialogo te lo dice prima con la rotta di ogni prodotto. Vale un controllo diverso: se nel magazzino di arrivo non ci sono piu' i pezzi da riportare indietro, quella riga viene bloccata e te lo dice, perche' tirarli fuori da un magazzino vuoto lascerebbe un totale negativo. La stanza di arrivo resta quella registrata, quindi i pezzi tornano nel magazzino giusto ma possono finire su un altro scaffale: se ti serve la stanza esatta, apri `Sposta` e rifai lo spostamento da li'.
- Se un prodotto che era nel movimento riaperto non e piu in lista, `Rettifica` lo aggiunge come ripristino esplicito, nella stessa operazione, con lo stesso controllo sullo stock attuale. Togliere un prodotto dal movimento non lo annulla da solo: senza questo passaggio, la merce restrebbe spostata e nessuno se ne accorgerebbe.
- Le tabelle del modulo usano la `DataGridView` condivisa del progetto.

## Dashboard

La `Dashboard` e la postazione rapida per controllare e analizzare i dati WooCommerce del negozio. Mostra il periodo attivo, vendite, ordini, prodotti, stock, clienti quando disponibili, andamento vendite e accessi ai dettagli gia presenti come top prodotti, performance e analisi ordini.

- Il menu periodo permette di cambiare l'intervallo attivo tra oggi, settimana, mese e anno; la dashboard ricarica i dati per quel periodo.
- Il pannello `Analisi dashboard` riepiloga il filtro attivo e distingue i dati gia analizzabili dai dati che richiedono aggregazioni future.
- Il pannello `Analisi dashboard` adatta disposizione, riepiloghi e pulsante report a layout smartphone, tablet e desktop.
- `Genera report` crea un file PDF o CSV usando il periodo e i dati attualmente caricati nella dashboard.
- Le scelte di export disponibili sono `Dashboard CSV`, `Dashboard PDF`, `Vendite CSV` e `Vendite PDF`.
- I report `Vendite` usano lo stesso periodo della dashboard e includono riepilogo vendite, top prodotti e tendenze disponibili.
- I filtri avanzati per vendite per brand, varianti e attributi non sono ancora controlli attivi nella dashboard: compaiono come capacita mancanti finche non esiste l'aggregazione dati corrispondente.

## Impostazioni

Le impostazioni sono raggruppate per responsabilita in tab dedicate.

- La tab `Generale` imposta la lingua dell'interfaccia e la sede in uso. Il selettore `Lingua` e una combobox: la prima voce e `Lingua di sistema` e riporta fra parentesi la lingua effettiva, cosi si vede su cosa cade la scelta; sotto trovi le lingue supportate con il nome nativo (`English`, `Italiano`). Il cambio si applica subito, senza riavvio, e si aggiornano subito le card della home, il menu laterale, la barra in alto e i titoli delle schede gia aperte, compreso il suffisso `#2` delle sezioni aperte in piu istanze. Il campo `Sede` con il bottone di salvataggio determina la sede usata nelle operazioni di cassa e inventario.
- La tab `Tema` imposta la modalita chiaro/scuro/sistema, il colore primario, la visibilita del report nella home e gli sfondi decorativi. L'opzione `Sfondo segue tema chiaro scuro` e attiva di default: con l'opzione attiva gli sfondi seguono il tema chiaro o scuro, con l'opzione disattivata usano il colore primario scelto. Il valore gia salvato viene rispettato, quindi la scelta resta quella fatta in precedenza.

## Consigli rapidi

- Usa `Impostazioni` per i parametri di inventario, immagini, IA, RFID e shortcut
- Nelle immagini prodotto l'app carica il file originale; se le dimensioni note superano le soglie configurate, nella libreria media compare un badge informativo accanto alla foto
- Se una pagina richiede accesso, fai login prima
- Per cassa, inventario e loyalty, il backend passa da MGWS
- Su Windows e Linux, usa `Aggiornamenti` per verificare nuove versioni desktop; quando installi un update l'app si chiude, affida l'installazione al processo Velopack e si riavvia automaticamente
- Dopo un aggiornamento desktop, l'app mostra una volta le note della release installata
