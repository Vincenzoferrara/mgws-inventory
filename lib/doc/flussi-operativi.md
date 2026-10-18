# Flussi Operativi

## Accesso

1. Inserisci URL
2. Scegli metodo di login
3. Entra nell'area Home; se MGWS e disponibile, l'app sincronizza le preferenze utente non segrete da `MGWS /me/settings` e le applica alla cache locale. Se il profilo remoto e vuoto, l'app inizializza MGWS con le preferenze locali non sensibili

## Nuovo prodotto

1. Apri `Nuovo Prodotto`
2. Compila dati base
3. Configura immagini e attributi; la libreria media segnala le foto oltre soglia ma non blocca la selezione
4. Salva

## Vendita in cassa

1. Apri `Cassa`
2. L'operatore e automaticamente l'utente con cui hai fatto login: lo scontrino registra il suo username; se l'identita non e disponibile la vendita non si blocca ma resta senza operatore
3. Se `Impostazioni > Cassa > Turno cassa obbligatorio` e attivo, apri il turno cassa dal pulsante `Apri turno`, indicando il fondo iniziale; l'app crea prima lo shift MGWS server-side, poi salva il turno locale con la stessa `shift_key`, associa il turno alla giornata `giorno|cassa` e blocca aggiunte/checkout finche non esiste un turno aperto. Se l'opzione e disattiva, il turno resta facoltativo e la vendita puo procedere senza `shift_id`.
4. Aggiungi prodotti o varianti dal campo barcode, dallo scanner barcode/QR a schermo intero oppure dal pulsante `Aggiungi manualmente`; il barcode aggiunge direttamente al carrello, segnala i codici inesistenti e blocca prodotti o varianti senza quantita disponibile
5. Controlla il carrello nel lato sinistro della cassa e modifica quantita, rimozioni o sconti riga dalla lista righe scontrino
6. Applica coupon se serve
7. Conferma checkout MGWS con payload POS e chiave idempotente quando disponibile; se il turno e aperto, il payload include anche il riferimento del turno cassa
8. MGWS crea l'ordine WooCommerce, registra movimenti stock e audit, aggiorna `mg_stock_levels` e restituisce l'ID ordine
9. Se la stessa chiave idempotente viene reinviata con lo stesso payload, MGWS restituisce la risposta salvata senza duplicare ordine o movimenti
10. Lo scontrino chiuso viene archiviato nello `Storico cassa` locale (canale `pos`) con righe, metodo pagamento, operatore, cassa, turno, totali e riferimento all'ordine Woo/MGWS; gli ordini WooCommerce restano un ciclo separato e compaiono solo come riferimento

## Storico cassa, resi vincolati e chiusura

1. Apri `Cassa > Storico cassa`
2. Filtra gli scontrini POS per cliente/numero/ordine, cassa, metodo pagamento o soli resi; l'elenco non include mai gli ordini WooCommerce come documenti primari
3. Apri il dettaglio per vedere righe vendita/reso, operatore, cassa, totali e ordine collegato
4. Per un reso, scegli la riga venduta: l'app mostra quantita venduta, gia resa e ancora rendibile, con prezzo realmente pagato; oltre il residuo il reso e bloccato e il motivo e obbligatorio. MGWS ripete il controllo server-side quando riceve `source_sale_id` e `source_line_key`.
5. Per un cambio, scegli `Cambio` sulla riga venduta: il carrello riceve la riga reso collegata e resta aperto per aggiungere il prodotto sostitutivo prima del checkout.
6. Lo scontrino chiuso puo ricevere solo rettifiche append-only o annullo motivato; gli scontrini annullati sono esclusi dai totali e non sono piu origine valida per nuovi resi.
7. Per la chiusura, usa `Chiudi turno` dalla cassa oppure `Chiusura` nello storico: l'app invia a MGWS solo contanti/carta contati, causale e note; MGWS calcola i totali attesi dagli ordini del turno e restituisce le differenze. Solo se la chiusura server riesce, il turno viene chiuso anche nello storico locale. La chiusura registrata non si modifica, solo note di rettifica append-only

## Dipendenti

1. Apri `Dipendenti`
2. L'elenco viene caricato da MGWS, non da dati demo locali
3. Aggiungi o modifica nome, cognome, email, ruolo e stipendio; lo stipendio accetta formati locali come `1500,00` o `1.500,00`, viene salvato in MGWS come centesimi interi e valuta, e non viene convertito silenziosamente a zero se non valido
4. Nel form puoi indicare l'`ID utente WordPress` se la persona ha un account sul sito; svuotando il campo il dipendente viene scollegato
5. Nel dettaglio, `Accesso e permessi` compare solo se il dipendente e collegato: gestisci ruoli e capability MGWS entro la whitelist dell'app
6. Nella stessa sezione trovi `Credenziali attive`, dove puoi revocare Application Password e chiavi WooCommerce del dipendente. L'app non le genera: l'Application Password del dispositivo e gia provisionata dal login wp-admin, quindi la revoca serve soprattutto in fase di offboarding
7. La sezione credenziali richiede un account amministratore WordPress; con un account non amministratore resta visibile la spiegazione del 403 e ruoli e capability continuano a funzionare
8. L'eliminazione disattiva il dipendente lato MGWS invece di cancellarlo distruttivamente, ma non revoca da sola le credenziali WordPress: la revoca resta un passo manuale nella sezione `Credenziali attive`

## Controllo inventario e stock MGWS

1. Apri `Prodotti`
2. Usa la barra comandi per cercare, filtrare per campo/operatore/valore, nascondere gli esauriti o cambiare ordinamento
3. Controlla nella griglia disponibilita, quantita, varianti e stato
4. Seleziona un prodotto per aprire il pannello dettaglio con foto, dati, modifica rapida e varianti; per i prodotti variabili vengono caricate tutte le pagine WooCommerce delle varianti prima di applicare i filtri locali
5. Seleziona piu prodotti se devi usare azioni di massa come deselezione o eliminazione
6. Verifica disponibilita e discrepanze sapendo che `mg_stock_levels` in MGWS e la sorgente autorevole dello stock gestionale
7. Quando crei o modifichi un prodotto, abilita `Inventario MGWS` nella sezione prezzi/stock se vuoi registrare subito lo stock gestionale totale finale: inserisci stock intero non negativo e motivo, poi salva il prodotto
8. Dopo il salvataggio prodotto riuscito, l'app usa il `product_id` salvato per inviare `Reconcile stock`; se il prodotto non ha ID valido, MGWS non viene chiamato e il feedback resta visibile
9. Apri `Inventario MGWS` per i flussi operativi di aggiunta prodotti e rettifica magazzino

## Fornitori e ordini fornitore

1. Apri `Fornitori` dalla home per gestire una lista in stile `Clienti`, alimentata dalla tabella MGWS `mg_fornitori`.
2. Usa `Aggiungi fornitore` per aprire il form dedicato: l'app crea un record fornitore MGWS, senza creare utenti WordPress o customer WooCommerce; la creazione non avviene direttamente nella lista.
3. I fornitori sono globali, non hanno una sede e non compaiono nella lista `Clienti`, che resta dedicata ai soli clienti compratori.
4. Ogni aggiunta merce, semplice o da ordine fornitore, richiede una sede esplicita.
5. In `Inventario MGWS`, un ordine fornitore puo andare in `pending` quando l'operatore chiede la verifica.
6. Una ricezione in `pending_verification` non muove stock finche un manager con capability `mgws_purchase_approve` non la convalida.
7. Alla convalida, MGWS carica lo stock, aggiorna le quantita ricevute e scrive `_purchase_cost` sul prodotto o sulla variante ricevuta.

## Aggiunta prodotti MGWS

1. Apri `Inventario MGWS` e scegli il modulo `Aggiungi` dal selettore in alto
2. Scegli la modalita: **Semplice** per caricare la merce senza legarla a un ordine, **Associato a un ordine** per generare una bozza ordine con le stesse righe
3. Se usi la modalita ordine, seleziona il fornitore e il documento; la spunta di convalida distingue l'ordine confermato da quello in bozza e mostra la differenza tra pezzi inseriti e pezzi convalidati
4. Cerca i prodotti con `Aggiungi prodotto esistente` o scansiona il barcode: con la spunta del modo rapico ogni barcode aggiunge la riga con un pezzo, ri-scansionandola i pezzi crescono; senza spunta l'app chiede la quantita
5. Scrivi `Dettagli` se l'operazione ha qualcosa da dire: e' facoltativo, ma se lo scrivi viaggia con il movimento
6. Controlla la conferma con motivo, righe e quantita totale
7. Conferma: l'app invia le righe a MGWS una alla volta con chiavi di idempotenza distinte e lo stock cambia subito per quelle che riescono

## Rettifica magazzino MGWS

1. Apri `Inventario MGWS` e scegli il modulo `Rettifica`
2. Scegli il verso con le radio `Incremento` o `Diminuzione`: stanno accanto alla spunta e rispondono alla domanda "quando scanno un barcode, aumento o diminuisco?", quindi sono visibili anche a lista vuota
3. Aggiungi i prodotti col barcode o con `Aggiungi prodotto esistente`; ogni riga mostra lo stock MGWS corrente e l'anteprima `prima -> dopo` col delta
4. Imposta i pezzi da correggere riga per riga con il contatore, oppure togli la spunta e scrivi in `Quantita contata` il valore assoluto che hai contato
5. Scrivi il motivo: e' obbligatorio, e i dettagli facoltativi finiscono dentro
6. Conferma: MGWS registra un movimento `adjust` per ogni riga. L'app non si ferma al primo errore e alla fine riporta quante righe sono passate e quali no

## Spostamento tra ubicazioni MGWS

1. Apri `Inventario MGWS` e scegli il modulo `Sposta`
2. Aggiungi i prodotti: ogni riga sceglie il magazzino di partenza fra quelli dove il prodotto e davvero presente, con i pezzi disponibili accanto
3. Indica la sede di arrivo; magazzino di arrivo, stanza, scaffale e ripiano sono facoltativi e, se restano vuoti, non vengono inviati
4. Imposta i pezzi da spostare senza superare quelli disponibili nella partenza
5. Scrivi il motivo: e' obbligatorio
6. Conferma: `stock/move` sposta i pezzi fra ubicazioni e **non cambia il totale del prodotto**

## Lettura e correzione dei movimenti MGWS

1. Apri `Inventario MGWS` e scegli il modulo `Movimenti`
2. Filtra per prodotto, variante, data, fonte, operatore o motivo. La lista mostra una riga per operazione, non per prodotto: MGWS scrive una riga per ogni prodotto toccato e l'app accorpa quelle che appartengono allo stesso movimento
3. Doppio clic, o l'azione di contesto `Apri il movimento`, apre la scheda con lo stock di ogni prodotto prima e dopo, o con i pezzi e la rotta `da -> a` se il movimento e' uno spostamento
4. `Modifica` riapre l'operazione nel modulo che l'ha prodotta, con i prodotti gia in lista e il suo dettaglio. Funziona su `Rettifica` e su `Sposta`: la rettifica riparte dal valore lasciato dal movimento, lo spostamento dagli stessi due magazzini. Non funziona su un carico, che sa solo aumentare lo stock, e in ogni caso di modulo non riprendibile il pulsante resta spento e spiega perche'
5. Se in un movimento riaperto togli un prodotto, `Rettifica` lo recupera come ripristino esplicito nella stessa operazione, perche' toglierlo dalla lista non basta a rimettere la merce a posto
6. `Annulla movimento` riporta ogni prodotto allo stock che aveva prima di quel movimento, e lo fa registrando un movimento nuovo: il ledger non si cancella ne si modifica, quindi lo storico mostra sia il fatto sia il suo annullamento, con il numero dell'originale nel motivo
7. Prima di annullare, l'app rilegge lo stock e lo confronta con quello che il movimento aveva lasciato: se un prodotto e stato intanto toccato da un'altra operazione, quella riga viene bloccata e ti viene detto quale, invece di azzerare anche il lavoro altrui
8. Su uno spostamento l'annullamento prende un'altra strada, perche' non si puo' togliere pezzi da uno scaffale che li ha solo spostati: registra uno spostamento al contrario, riportando gli stessi pezzi dal magazzino di arrivo a quello di partenza. Il dialogo mostra la rotta di ogni prodotto prima di confermare, e il controllo e' un altro: si verifica che i pezzi siano ancora nel magazzino di arrivo, non che il totale sia invariato

## Riordino e ordini fornitore MGWS

Le schermate `Fornitori`, `Riordino` e `Ordini Fornitore` non sono oggi raggiungibili: il selettore dei moduli non le espone. Le rotte MGWS e il codice dei pannelli esistono, e quando torneranno in un modulo resteranno stock-neutral.

1. `Fornitori` per creare, modificare, inattivare o gestire cancellazioni protette dei fornitori
2. `Riordino` per leggere suggerimenti da soglie MGWS, rimandare un suggerimento o creare una bozza ordine
3. `Ordini Fornitore` per creare o aggiornare bozze, righe prodotto/variante, quantita, costo e stato ordine
4. Considera questi passaggi stock-neutral: fornitore, suggerimento, bozza e ordine non aumentano giacenza

## Ricezione e convalida MGWS

Anche `Ricezione/Convalida` non e oggi raggiungibile dal selettore dei moduli. Il flusso, quando ripristinato, resta com'e: la bozza non modifica stock e solo la convalida lo cambia.

1. Carica gli ordini e le ricezioni MGWS
2. Crea o aggiorna una bozza di ricezione con quantita ricevute, respinte, backorder e motivi richiesti
3. Lascia la bozza aperta finche la merce non e controllata: la bozza non modifica stock
4. Usa `Convalida` solo quando vuoi registrare lo stock ricevuto
5. MGWS applica un solo movimento idempotente per la convalida e blocca i doppi invii o payload in conflitto

## Carte fedelta MGWS

1. Apri `Carte Fedelta`
2. Cerca il cliente per ID, carta o email tramite rotte MGWS v1; la scansione della carta usa lo scanner condiviso a schermo intero
3. Aggiungi o sottrai punti con riferimento e nota se servono per audit
4. Consulta lo storico punti dalla rotta history, ordinato dal movimento piu recente
5. Se rimuovi una carta, MGWS cancella solo il numero carta: conto cliente e storico movimenti restano disponibili

## Personalizzazione dashboard e generazione report

1. Apri `Dashboard` e scegli la dashboard dal nome in alto
2. Imposta i filtri: periodo, confronto col periodo precedente, stati ordine
3. Premi `Personalizza dashboard`, aggiungi o modifica i widget scegliendo dato e tipo di grafico, trascinali nella posizione voluta e regola larghezza e altezza
4. Da `Nome e visibilita` scegli `Solo io`, `Tutti` o `Solo admin` (la condivisione e riservata ai gestori del negozio)
5. Premi `Salva`: layout, visibilita e filtri vengono salvati in MGWS
6. Per un report, apri `Altre opzioni` > `Esporta report` e scegli `Dashboard CSV`, `Dashboard PDF`, `Vendite CSV` o `Vendite PDF`
7. L'app genera e condivide il file usando i dati caricati e il periodo filtrato

## Gestione dettaglio prodotto

1. Apri `Prodotti`
2. Seleziona una riga della griglia
3. Usa il pannello dettaglio per consultare immagini, categorie, tag, stato, prezzo, sconto e marca
4. Usa `Modifica rapida` per aggiornare categorie, tag, stato o dati varianti disponibili dopo il caricamento completo delle pagine varianti WooCommerce
5. Usa i filtri varianti per restringere taglia, colore o altri attributi e, se serve, mostra solo varianti disponibili
6. Usa il menu azioni del dettaglio per modificare, eliminare o creare un prodotto

## Template e stampa

1. Apri `Template e stampa` (serve MGWS).
2. Nella tab `Stampa` tocca un modello nel suo gruppo.
3. Imposta copie, posizioni gia usate e formato carta guardando l'anteprima.
4. Premi `Stampa` o `Salva PDF`.

## Stampa etichette dai prodotti

1. In `Prodotti` seleziona i prodotti.
2. Premi `Stampa etichette` nella barra o nel menu del tasto destro.
3. Nella tab `Stampa` scegli il modello di etichetta.
4. Controlla le etichette di ogni variante (una per pezzo in magazzino), togli con `Elimina` le righe da non stampare e aggiungi altri prodotti con `Aggiungi etichetta`.
5. Premi `Stampa`.

## Nuovo modello

1. Nella tab `Template` premi `Nuovo modello` (solo responsabili).
2. Scegli nome, tipo, categoria e formato carta.
3. Disegna nel designer trascinando i campi sull'etichetta.
4. Premi `Usa queste modifiche`: il modello e salvato su MGWS.
