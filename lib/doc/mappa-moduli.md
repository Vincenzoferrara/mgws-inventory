# Mappa Moduli

## Home

La schermata iniziale usa una docking layout su desktop e un flusso piu semplice su schermi piccoli. Il drawer mostra la versione pubblica dell'app letta dai metadati runtime, usando la sintassi GitHub `major.minor.build` senza mostrare il suffisso tecnico Flutter `+build`.
La barra in alto mostra a destra il pulsante log e lo stato login: avatar e nome dell'utente WordPress con stato `Online`, `Verifica...` durante il controllo o `Accedi` se non autenticato; il menu dell'account contiene il logout.

## Moduli disponibili

- `Cassa` - punto vendita con turno cassa esplicito, aggiunta prodotti da barcode/QR o selezione manuale, carrello a lista righe sul lato sinistro, checkout MGWS idempotente, ordine WooCommerce e audit movimenti; la voce `Storico cassa` conserva lo storico scontrini POS (canale `pos`) con resi vincolati alla riga venduta e chiusure turno, separato dagli ordini Woo
- `Prodotti` - gestione catalogo con pannello `Filtro`, `DataGridView` condivisa su desktop e Android, selezione multipla, pannello dettaglio prodotti/varianti e letture inventario MGWS. La sezione ha una sola cornice, quella del pane: griglia e barra di paginazione non ne aggiungono una propria, e la griglia usa `framed: false` per non sottrarre spazio alle colonne
- `Inventario MGWS` - schermata operativa su quattro moduli scelti da un selettore: `Aggiungi`, `Rettifica`, `Sposta` e `Movimenti`
- `Nuovo Prodotto` - creazione articolo con selezione immagini originali, avvisi informativi sulle dimensioni oltre soglia e rettifica stock totale MGWS opzionale dopo il salvataggio
- `Coupon` - gestione sconti
- `Ordini` - lista e dettaglio ordini
- `Clienti` - gestione clienti
- `Fornitori` - lista in stile `Clienti` dei fornitori salvati nella tabella MGWS `mg_fornitori`; creazione tramite `Aggiungi fornitore` dedicato, senza creare utenti WordPress o customer WooCommerce
- `Carte Fedelta` - punti, carta cliente, lookup e storico loyalty tramite MGWS v1
- `Template e stampa` - stampa etichette prodotto, cartelli negozio e report A4 e gestisce modelli, categorie e formati carta salvati su MGWS (rotte `/print`); solo con MGWS
- `Dashboard` - dashboard a widget personalizzabili (personali, condivise con tutti o solo admin) con filtri periodo e stati ordine, scelta del tipo di grafico, dettagli e generazione PDF/CSV
- `Impostazioni` - backend, prodotti, tema, IA, RFID, shortcut
- `Aggiornamenti` - aggiornamenti desktop Windows/Linux via Velopack e note release post-riavvio
- `CalDAV` - calendario e contatti
- `Dipendenti` - gestione personale, collegamento opzionale all'utente WordPress e permessi MGWS del dipendente collegato
- `DataGridView` - pagina tecnica di test

## Note di navigazione

- Alcuni moduli sono singleton e si riaprono nella stessa scheda
- Alcuni moduli possono avere istanze duplicate
- Su mobile l'app mostra una singola vista alla volta

## Confini MGWS nei moduli

- `Cassa` usa MGWS per il checkout POS; WooCommerce conserva l'ordine creato dal plugin; lo storico scontrini POS locale (SharedPreferences/JSON) e separato dagli ordini Woo, attribuisce ogni scontrino all'utente loggato come operatore e lo collega al turno cassa aperto. Il payload invia a MGWS i riferimenti `_canale`, `_numero_scontrino_pos`, `_operatore_id`, `_operatore_nome`, `_cassa_nome`, `_sede`, `_giornata_id`, `_turno_id`, `shift_id`, `source_sale_id`, `source_line_key`, `return_reason` e `return_outcome` per il futuro enforcement server-side
- `Prodotti` consulta catalogo e disponibilita e puo registrare stock iniziale/totale MGWS durante creazione o modifica prodotto
- `Inventario MGWS` contiene i moduli operativi `Aggiungi`, `Rettifica` e `Sposta`, piu il modulo di sola lettura `Movimenti`; i tre operativi condividono la sezione prodotti e il campo `Dettagli`, e lavorano tutti su piu righe in una sola operazione
- `Aggiungi` e document-free e muta stock solo dopo conferma, con movimento MGWS auditato
- `Rettifica` porta ogni prodotto a un valore assoluto con `stock/reconcile`; `Sposta` usa `stock/move`, che non cambia il totale del prodotto e non puo' sostituire la rettifica
- `Movimenti` legge il ledger MGWS e lo raggruppa per operazione invece che per prodotto; non lo modifica, e le azioni che scrivono dal ledger sono l'annullamento (contromovimento, o spostamento al contrario su uno spostamento) e la riapertura in un pannello, che registra solo se l'operatore conferma
- I pannelli di fornitori, riordino, ordini fornitore e ricezioni esistono nel codice ma il selettore dei moduli non li espone: restano fuori dal percorso operativo finche non vengono rimessi nel selettore
- `Carte Fedelta` usa MGWS per conto loyalty, carta, punti e storico; rimuovere una carta non rimuove conto o movimenti
- I report generati dalla `Dashboard` esportano in PDF/CSV i dati caricati nel periodo corrente; il modulo `Template e stampa` resta dedicato a etichette, cartelli e stampe.
- I report gestionali MGWS restano distinti dal modulo inventario descritto qui
- `Clienti` resta dedicato ai clienti WooCommerce; ruoli e capability WordPress non si gestiscono da li.
- `Dipendenti` usa le anagrafiche MGWS come sorgente principale. Ruoli e capability sono disponibili solo per i dipendenti con `wp_user_id` collegato, cosi l'app non gestisce permessi per utenti WordPress generici non dipendenti.
