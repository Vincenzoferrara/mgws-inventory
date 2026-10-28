# Todo

Backlog unico del progetto. Contiene idee, task e dubbi ancora aperti; ogni voce deve spiegare cosa va fatto, perché e come verificarlo. Se resta aperto qualcosa, va sempre aggiunto qui invece di lasciarlo nel log.

## Regole

- La documentazione tecnica attuale resta in `lib/doc`.
- Quando una voce viene implementata,  rimuoverla.

## Verifiche aperte repository Flutter

- [ ] Verificare il motore report MGWS su un WordPress reale
  - tipo: verifica/manuale
  - priorita: high
  - obiettivo: confrontare `POST /mgws/v1/reports/query` con i totali di WooCommerce e delle chiusure cassa su dati veri
  - perche: il motore e' stato provato su MariaDB con tabelle minime e dati inventati, non su un sito con le tabelle analytics popolate da WooCommerce; i rimborsi online sono letti come righe con `parent_id` e quantita negative, da confermare sulla versione WooCommerce in uso
  - rischio: con WooCommerce Analytics disattivato o non ancora sincronizzato gli ordini online mancano (`online_included: false` o righe in ritardo)
  - verifica minima: incasso del mese da report uguale a scontrini MGWS + ordini online di WooCommerce; un utente senza `mgws_reports_read` riceve 403

- [ ] Fasi successive della reportistica completa
  - tipo: app/report
  - priorita: medium
  - obiettivo: ordini online (evasione, spedizioni, paesi), magazzino e acquisti nel motore report, tabella a piu colonne, heatmap ora per giorno, matrice taglia per colore, margini dal costo medio dei ricevimenti (`_purchase_cost`), dashboard pronte per area, schede prodotto e cliente con dettaglio al clic, obiettivi di vendita
  - perche: la fase 1 copre vendite, prodotti, clienti e cassa; il piano approvato prevede queste fasi
  - verifica minima: ogni fase aggiunge misure al catalogo MGWS e le rende sceglibili nell'editor

- [ ] Verificare le dashboard personalizzabili su un sito MGWS reale
  - tipo: verifica/manuale
  - priorita: high
  - obiettivo: controllare le rotte `GET/PUT/DELETE /mgws/v1/dashboards` con un amministratore e con un utente non gestore
  - perche: pagina, griglia, trascinamento e grafici sono stati verificati solo con dati finti; il plugin non e stato provato su WordPress, e `mgws_contract_test.php` non copre ancora le nuove rotte
  - verifica minima: l'admin crea una dashboard `Tutti` e una `Solo admin`; l'utente normale vede solo la prima, in sola lettura, riceve 403 se prova a salvarla e puo duplicarla come personale

- [ ] Valutare filtri dashboard per categoria/brand lato dati
  - tipo: decisione/prodotto
  - priorita: low
  - obiettivo: decidere se aggregare vendite per categoria, brand o variante con filtro globale
  - perche: oggi i filtri globali sono periodo, confronto e stati ordine; per widget c'e solo filtro testuale e limite, perche i report WooCommerce non filtrano per categoria senza scaricare tutti gli ordini
  - verifica minima: scelta documentata in `lib/doc/guida-sviluppatori.md`

- [ ] Verificare il comportamento delle card MGWS-only su installazione senza tabelle MGWS
  - tipo: verifica/manuale
  - priorita: high
  - obiettivo: controllare che cassa, inventario, fornitori, carte fedelta' e dipendenti restino chiusi con l'avviso giusto quando il plugin MGWS e' installato ma le tabelle non esistono
  - perche: `MgwsAuth` distingue backend non raggiungibile, servizio disabilitato (`enabled: false`) e sessione assente, ma la distinzione e' stata verificata solo con la lettura del codice, non su un'installazione reale con tabelle mancanti
  - rischio: se il plugin risponde 200 con `enabled: true` anche senza tabelle, MGWS risulterebbe disponibile e le sezioni si aprirebbero su chiamate che falliscono sul campo
  - verifica minima: su un sito MGWS con tabelle non installate, ogni card MGWS-only mostra l'avviso di servizio disabilitato e non apre la scheda

- [ ] Decidere se prodotti e nuovo prodotto devono diventare MGWS-only
  - tipo: decisione/prodotto
  - priorita: medium
  - obiettivo: scegliere se la riconciliazione stock MGWS in creazione prodotto deve bloccare la scheda o restare un'azione facoltativa
  - perche: prodotti e nuovo prodotto restano apribili senza MGWS per scelta, e la riconciliazione fallisce con un avviso; se in pratica la riconciliazione e' sempre necessaria, aprire la scheda senza backend e' solo un modo per arrivare a un errore
  - nota: servono piu' conferme sul flusso reale del negozio prima di rendere bloccanti queste due sezioni
  - verifica minima: decisione documentata in `lib/doc/modules-map.md` e applicata al flag della sezione

- [ ] Valutare il re-check periodico di MGWS durante una sessione lunga
  - tipo: decisione/prodotto
  - priorita: low
  - obiettivo: decidere se MGWS vario verificato periodicamente mentre l'app e' aperta, o solo all'avvio e su azione esplicita
  - perche: `MgwsConnection.ensureConnected()` usa lo stato della catena di login per tutta la sessione; se MGWS si ferma a meta' sessione, le sezioni gia' aperte restano visibili e falliscono operazione per operazione
  - rischio: senza re-check, l'utente vede l'errore solo quando agisce; con re-check continuo, si aggiunge traffico inutile su una connessione stabile
  - verifica minima: scelta documentata in `lib/doc/architecture.md`

- [ ] Collegare i dati reali ai report di stampa
  - tipo: app/plugin/report
  - priorita: high
  - obiettivo: riempire i modelli di tipo report (chiusura cassa, vendite, magazzino, movimenti) con dati MGWS reali invece dei numeri di esempio
  - perche: le etichette da Prodotti usano gia i dati veri, i report invece mostrano `Dati di esempio`
  - nota: le chiavi (`incassoTotale`, `pagamenti`, `giacenze`, `movimenti`, ...) sono salvate nei modelli: i dati reali devono produrre le stesse chiavi
  - verifica minima: un report stampato mostra dati MGWS e non la scritta `Dati di esempio`

- [ ] Verificare nell'app la sezione Template e stampa con un utente reale
  - tipo: verifica/manuale
  - priorita: high
  - obiettivo: con un responsabile, aprire la sezione su un sito nuovo (carica i predefiniti una volta), creare/modificare/eliminare modelli, categorie e formati, e stampare etichette da Prodotti su variabili con colore e taglia
  - perche: le rotte `/print` sono state provate dentro WordPress e il codice dell'app compila, ma il flusso completo nell'app non e stato provato con un login reale
  - verifica minima: dopo il riavvio dell'app su un altro dispositivo si vedono gli stessi modelli; un dipendente senza permessi vede l'avviso e non puo modificare

- [ ] Verificare la stampa reale di etichette e cartelli su stampanti fisiche
  - tipo: verifica/manuale
  - priorita: medium
  - obiettivo: controllare allineamento su fogli A4 adesivi (3x8, 3x7, 4x10, 5x13) e su rotoli termici, con la finestra di stampa del sistema su Linux, Windows e Android
  - perche: verificato solo l'anteprima PDF; driver e dialoghi di stampa possono applicare margini o "adatta alla pagina" che spostano le etichette
  - verifica minima: una stampa di prova su foglio adesivo cade dentro i bordi di ogni etichetta

- [ ] Report di stampa su piu pagine
  - tipo: app/report
  - priorita: low
  - obiettivo: far continuare le tabelle dei report su pagine successive quando le righe non entrano nell'area disegnata
  - perche: il renderer disegna una pagina per modello e taglia le righe in eccesso della tabella
  - verifica minima: un report movimenti con 200 righe stampa tutte le righe

## Priorita reale MGWS da portare anche nell'app Flutter

- [x] MGWS/App: chiusura cassa giornaliera completa
  - tipo: app/plugin/UI
  - priorita: high
  - obiettivo: aggiungere turno cassa, fondo iniziale, totali per metodo pagamento, rimborsi, differenza reale/attesa, note operatore e report di chiusura
  - perche: il gestionale deve riconciliare cassa fisica e POS, non solo creare ordini
  - grafica app: schermata apertura turno, pannello riepilogo giornaliero, form chiusura con contanti reali, differenze evidenziate, stampa/export
  - stato app/plugin: enforcement turno cassa MGWS completato end-to-end; l'app apre `POST /pos/shifts` prima del turno locale, usa la `shift_key` come `shift_id` checkout, blocca apertura/chiusura locale se MGWS rifiuta, e chiude `POST /pos/shifts/{shift_key}/close` inviando solo contanti/carta contati; MGWS calcola expected totals dagli ordini collegati allo shift e blocca checkout senza shift aperto valido server-side. UI chiusura turno aggiunta nelle impostazioni cassa.
  - resta aperta per: stampa/export chiusura e report gestionale storico delle chiusure
  - verifica minima: un turno raccoglie vendite e resi e genera chiusura con totali coerenti


- [ ] MGWS/App: marginalita e costi prodotto/variante/vendita
  - tipo: app/plugin/report/UI
  - priorita: high
  - obiettivo: salvare costo fornitore/storico costo e calcolare margine lordo per prodotto, variante, scontrino e periodo
  - perche: fatturato e vendite non dicono quanto si guadagna realmente
  - grafica app: campi costo dove appropriato, riepilogo margine nei dettagli vendita/prodotto e report marginalita
  - verifica minima: una vendita con costo noto mostra margine coerente nei report MGWS/app

- [ ] MGWS/App: report gestionali MGWS reali
  - tipo: app/plugin/report/UI
  - priorita: high
  - obiettivo: aggiungere report MGWS per vendite POS, resi, cambi, movimenti, chiusure cassa, fornitori, riordini e marginalita
  - perche: le statistiche stock/loyalty attuali non coprono la gestione completa del negozio
  - grafica app: dashboard/report con filtri periodo, esportazione, dettaglio drill-down e indicatori coerenti col tema globale; includere report di chiusura con storico chiusure passate, differenze, operatori, cassa, sede, metodo pagamento e rettifiche
  - verifica minima: report basati su dati MGWS reali, non su cache locale o dati finti

- [ ] MGWS/App: implementare bene il modulo report con grafica completa
  - tipo: app/plugin/report/UI
  - priorita: high
  - obiettivo: trasformare i report in una sezione gestionale completa con dati MGWS reali, viste dedicate, filtri, riepiloghi, drill-down, esportazione e grafica coerente con il tema globale
  - perche: i report devono servire davvero alla gestione del negozio, non essere solo schermate dimostrative o statistiche parziali
  - grafica app: dashboard report, card KPI, tabelle filtrabili, dettaglio movimenti/vendite/resi, report inventario, report cassa, storico chiusure turno/giornata, export PDF/CSV e stati di caricamento/errore chiari
  - verifica minima: ogni report usa endpoint/dati MGWS reali, dichiara la fonte dei dati, gestisce vuoti/errori e produce risultati coerenti con vendite, inventario e movimenti

- [ ] MGWS/App: anagrafiche controllate per taglie, colori, reparti e localita
  - tipo: app/plugin/UI
  - priorita: medium
  - obiettivo: decidere quali anagrafiche gestionali controllare in MGWS, come taglie, colori, reparti, stagioni e localita
  - perche: categorie/tag/attributi WooCommerce coprono l'e-commerce, ma il negozio fisico puo richiedere vocabolari controllati
  - grafica app: gestione anagrafiche controllate solo dove utile
  - verifica minima: la scelta architetturale e documentata e le anagrafiche scelte non generano duplicati operativi

- [ ] MGWS/App: controlli eliminazione e soft delete su entita usate
  - tipo: app/plugin/sicurezza/UI
  - priorita: medium
  - obiettivo: impedire cancellazioni distruttive di fornitori, anagrafiche, clienti, prodotti o ubicazioni usate da vendite, resi, ordini, movimenti o inventari
  - perche: storico contabile e audit non devono rompersi per cancellazioni dirette
  - grafica app: messaggi chiari, stato inattivo dove serve e azioni disabilitate quando l'entita e referenziata
  - verifica minima: eliminare un'entita usata restituisce errore gestionale comprensibile e non rompe lo storico

- [ ] Traduzione multilingua completa dell'app
  - tipo: idea
  - priorita: medium
  - obiettivo: tradurre UI, messaggi e contenuti visibili all'utente
  - note: richiede scelta tecnologia di localizzazione e fallback lingua

- [ ] Dashboard KPI negozio
  - tipo: idea
  - priorita: medium
  - obiettivo: mostrare vendite giornaliere, margini, rotazione articoli
  - note: le metriche vere dovrebbero arrivare da MGWS

- [ ] Pagina admin movimenti magazzino (plugin WordPress)
  - tipo: idea
  - priorita: medium
  - obiettivo: inserire carico/scarico/rettifica con audit trail
  - note: filtri per prodotto, data, operatore

- [ ] Sync bidirezionale WooCommerce stock
  - tipo: idea
  - priorita: medium
  - obiettivo: allineare giacenze tra plugin e catalogo WooCommerce
  - note: usare coda asincrona con idempotenza

- [ ] Alert soglia minima scorte
  - tipo: idea
  - priorita: medium
  - obiettivo: notificare admin quando un articolo scende sotto soglia
  - note: evitare spam notifiche duplicate

- [ ] Pattern globale GUI/CODE su tutte le pagine gestionali
  - tipo: idea
  - priorita: medium
  - obiettivo: standardizzare la divisione tra `*.gui.dart` e `*.code.dart`
  - note: applicare progressivamente a ordini, clienti, coupon e report


- [ ] MGWS come backend nativo completo per il dominio custom WordPress
  - tipo: idea
  - priorita: high
  - obiettivo: far parlare l'app solo con `MGWS` o WooCommerce e spostare dentro MGWS le funzioni custom
  - note: inventario, stock, loyalty, report, fornitori, riordini

- [ ] Checkout cassa diretto su MGWS
  - tipo: idea
  - priorita: high
  - obiettivo: far passare il checkout da un unico endpoint MGWS che valida il carrello, crea l'ordine WooCommerce e registra movimenti e audit
  - note: payload con vendite, resi e cambi

- [ ] Moduli MGWS per report gestionali
  - tipo: plugin
  - priorita: high
  - obiettivo: completare il dominio report custom dentro MGWS; fornitori e riordini inventory sono gia coperti dal modulo MGWS inventario/restock

- [ ] Chiusura cassa giornaliera
  - tipo: app/plugin
  - priorita: high
  - obiettivo: gestire apertura turno, fondo cassa, incassi per metodo pagamento, rimborsi, differenza cassa e chiusura giornaliera
  - perche: per uso reale in negozio serve riconciliare contanti/POS e avere un report di fine giornata distinto dalla dashboard vendite
  - dettagli: apertura/chiusura turno e enforcement checkout completati tramite MGWS server-side; la chiusura invia solo i valori contati e usa expected totals calcolati dal plugin dagli ordini dello shift
  - resta aperta per: stampa/export chiusura e report storico chiusure
  - verifica minima: un turno cassa aperto raccoglie vendite e resi, poi genera una chiusura con totali coerenti e differenza calcolata; `flutter analyze` pulito lato app


- [ ] Marginalita reale per prodotto, variante e vendita
  - tipo: app/plugin
  - priorita: high
  - obiettivo: calcolare margine lordo usando prezzo vendita, prezzo acquisto e quantita vendute
  - perche: la dashboard vendite da sola non dice quali prodotti sono profittevoli; serve distinguere fatturato da guadagno
  - dettagli: costo fornitore per variante, storico costo, margine su scontrino, margine per prodotto/categoria/periodo, prodotti molto venduti ma poco profittevoli
  - verifica minima: una vendita con prezzo acquisto noto mostra margine lordo coerente nei report


- [ ] Anagrafiche gestionali controllate per taglie, colori, reparti e localita
  - tipo: app/plugin
  - priorita: medium
  - obiettivo: decidere quali anagrafiche devono essere controllate da MGWS e quali restano tassonomie WooCommerce
  - perche: categorie/tag/attributi WooCommerce coprono l'e-commerce, ma il negozio fisico puo richiedere vocabolari controllati per taglia, colore, reparto, stagione, citta/CAP/provincia
  - dettagli: mappatura con attributi WooCommerce, prevenzione duplicati, uso nei prodotti e negli indirizzi, blocco eliminazione se usate
  - verifica minima: la scelta architetturale e documentata e almeno taglie/colori principali non generano duplicati operativi

- [ ] Controlli eliminazione su entita usate
  - tipo: app/plugin
  - priorita: medium
  - obiettivo: impedire cancellazioni distruttive di clienti, fornitori, anagrafiche o prodotti referenziati da vendite, resi, ordini o movimenti
  - perche: un gestionale reale deve preservare storico contabile e audit; non basta affidarsi agli errori API generici
  - dettagli: messaggi chiari per entita usate, soft delete dove serve, stato inattivo al posto di cancellazione, controlli server-side MGWS
  - verifica minima: provare a eliminare un'entita usata restituisce errore gestionale comprensibile e non rompe lo storico


- [ ] Spostare metriche cassa vere su MGWS
  - tipo: app/plugin
  - priorita: medium
  - obiettivo: usare MGWS come fonte affidabile per vendite, resi, cambi e saldo netto
  - note: SharedPreferences può restare solo come cache locale

- [ ] Correggere adattamento UI su dispositivi mobili
  - tipo: bug/UI
  - priorita: high
  - obiettivo: rendere le schermate principali realmente responsive su smartphone e tablet
  - perche: l'app non si adatta bene ai dispositivi mobili e rischia layout troppo larghi, popup scomodi o contenuti difficili da usare
  - verifica minima: provare le schermate principali su Android mobile con larghezze strette; nessun contenuto operativo deve uscire dallo schermo o richiedere interazioni desktop



- [ ] Completare aggiorna in massa in Gestione prodotti
  - tipo: app
  - priorita: high
  - obiettivo: completare la `Modifica in massa` in `Prodotti > Gestisci` oltre a categorie/tag_merge/stato/eliminazione gia presenti
  - perche: oggi il bulk copre solo categorie (merge), tag (merge), stato ed eliminazione (`lib/prodotti/prodotti_gestisci/prodotti_gestisci_view.gui.dart:484-527`); prezzi, prezzo scontato e quantita varianti funzionano solo sul singolo prodotto (`variantResult` solo `!isMulti`), mancano scelta merge vs replace, retry/errori parziali e UX mobile dedicata
  - dettagli: prezzi/sconti/quantita su selezione multipla, merge vs replace per categorie/tag, anteprima modifiche con conteggio interessati, errori parziali con retry, conferma non distruttiva, layout mobile senza overflow
  - verifica minima: selezione multipla aggiorna prezzi/stato/categorie su N prodotti con riepilogo successi/fallimenti; nessun `0` fuorviante; `flutter analyze` mirato pulito e doc `lib/doc` aggiornata se cambia comportamento

- [ ] Harden error handling batch categorie
  - tipo: app
  - priorita: low
  - obiettivo: gestire retry, errori parziali e chunk


## Architettura e regole operative

- [ ] Scrivere spiegazione completa dell'architettura desiderata
  - tipo: documentazione/architettura
  - priorita: high
  - obiettivo: descrivere come deve funzionare l'intero software, quali responsabilita ha l'app Flutter, quali responsabilita ha MGWS, cosa resta a WooCommerce, come scegliere dove mettere il codice e come deve ragionare un'IA quando modifica il progetto
  - perche: `lib/doc/architettura.md` e troppo sintetico e non basta a guidare scelte future coerenti
  - verifica minima: regole chiare per cartelle, file `*.gui.dart`/`*.code.dart`, backend ammessi, flussi business, sicurezza, test e documentazione aggiornata

- [ ] Rendere il tema globale obbligatorio per tutta l'app
  - tipo: architettura/UI
  - priorita: high
  - obiettivo: ogni implementazione grafica deve leggere colori, spaziature, typography e stile dal tema globale prima di definire UI custom
  - perche: l'app deve mantenere coerenza visiva ovunque e non deve avere schermate con colori o stili hardcoded scollegati dal tema
  - regola: prima di creare o modificare una UI, verificare `Theme.of(context)`, `ThemeSettings` e i componenti/stili condivisi gia esistenti
  - divieto: evitare colori, font, padding e stili hardcoded se esiste una scelta equivalente nel tema o in un componente condiviso
  - verifica minima: cambio tema chiaro/scuro o colore primario si riflette correttamente anche nella nuova schermata

- [ ] Rimuovere lo shim barcode morto in `lib/reuse_class/gui/barcode_scanner.dart`
  - tipo: architettura/pulizia
  - priorita: low
  - obiettivo: eliminare il file re-export che punta a `lib/reuse_class/barcode/barcode_scanner.dart` e che nessun file importa
  - perche: tutte e 5 le schermate che usano lo scanner importano gia il path canonico, quindi lo shim e un secondo modo di arrivare allo stesso file e crea due fonti di verita per il modulo barcode
  - verifica minima: `grep -rn "reuse_class/gui/barcode_scanner" lib` non restituisce nulla e `flutter analyze` resta pulito

- [ ] Decidere il destino di `DeviceUtils` in `lib/reuse_class/device_utils/`
  - tipo: architettura/pulizia
  - priorita: low
  - obiettivo: il file e stato spostato in `reuse_class` su richiesta esplicita, ma non ha nessun caller in tutto il progetto: decidere se eliminarlo o se iniziare a usarlo
  - perche: `architettura.md` dice che in `reuse_class` finisce solo codice usato da piu schermate, e `DeviceUtils` non e usato da nessuna; l'app gia classifica il dispositivo con `MediaQuery` in `home/`
  - verifica minima: se si usa, almeno una schermata mobile/desktop lo richiama al posto del controllo inline; se si elimina, `flutter analyze` pulito senza riferimenti


## Audit esteso 2 - utenti, clienti, dipendenti

- [ ] Clienti: esporre o rimuovere `eliminaCliente` non collegato alla UI
  - tipo: bug/app
  - priorita: medium
  - obiettivo: allineare controller e schermata clienti; creazione e modifica sono gia' state tolte dal controller (prendevano `WooCustomer`), resta l'eliminazione senza un comando nella lista

- [ ] Chiarire clienti WooCommerce vs clienti gestionali MGWS
  - tipo: architettura/app-plugin
  - priorita: high
  - obiettivo: definire se il dominio clienti resta WooCommerce diretto o se serve un gateway MGWS dedicato per dati gestionali aggiuntivi

- [ ] Utenti: implementare o rimuovere FAB `Aggiungi Utente`
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare un pulsante visibile ma vuoto

- [ ] Utenti: disabilitare `Salva Modifiche` quando non ci sono capability modificabili
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare errori inutili e messaggi di errore senza modifiche reali

- [ ] Utenti: rimuovere assunzione `true // Assume admin`
  - tipo: sicurezza/app
  - priorita: high
  - obiettivo: evitare che la UI costruisca permessi come se l'utente fosse sempre admin

- [ ] Utenti: proteggere generazione App Password e Woo API Key con autorizzazioni forti
  - tipo: sicurezza/app-plugin
  - priorita: high
  - obiettivo: evitare esposizione di segreti sensibili a utenti non autorizzati

## Audit esteso 3 - caldav, dashboard, settings, ai

Nota: CalDAV e' nascosto dalla home finche' non e' pronto (flag di build `CALDAV`, default `false`, in `lib/home/home.gui.dart`). Le voci CalDAV qui sotto servono prima di riattivarlo; `CalDavLoginTab` in `lib/login/gui/caldav_login.gui.dart` non e' usato da nessuna schermata.

- [ ] CalDAV: bloccare Basic Auth su HTTP
  - tipo: bug/security
  - priorita: high
  - obiettivo: impedire invio credenziali su connessioni non cifrate

- [ ] CalDAV/CardDAV: allineare documentazione e implementazione contatti
  - tipo: bug/doc
  - priorita: medium
  - obiettivo: evitare che la doc prometta una rubrica mentre il codice non la implementa davvero

- [ ] CalDAV: parsare eventi/task invece di mostrare solo `href`/`etag`
  - tipo: bug/app
  - priorita: medium
  - obiettivo: rendere i dati CalDAV leggibili e utili all'utente

- [ ] CalDAV: mostrare errori reali invece di liste vuote
  - tipo: bug/app
  - priorita: medium
  - obiettivo: distinguere nessun dato da errore di rete/autenticazione/xml

- [ ] Dashboard: correggere cache periodi custom
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare che due periodi personalizzati diversi riusino dati vecchi

- [ ] Dashboard: rendere robusto cast `low_stock_products`
  - tipo: bug/app
  - priorita: medium
  - obiettivo: gestire la forma tipica del JSON senza cast fragili

- [ ] Dashboard: collegare export report a `ReportExporter`
  - tipo: bug/app
  - priorita: low
  - obiettivo: usare davvero il servizio di export gia presente

- [ ] Ads: evitare dati zero o finti per Google Ads
  - tipo: bug/app
  - priorita: medium
  - obiettivo: non mostrare metriche ingannevoli quando il fetch e disattivato

- [ ] Ads: completare insights Meta Ads o marcarli non implementati
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare aggregati incompleti o parziali

- [ ] CSV dashboard export: escapare separatori, newline e formule
  - tipo: bug/security
  - priorita: medium
  - obiettivo: evitare CSV rotto o CSV injection

- [ ] Settings: rendere `AppSettings` stato app-wide se deve guidare tutta l'app
  - tipo: architettura/app
  - priorita: high
  - obiettivo: evitare che impostazioni globali siano create solo dentro la pagina settings

- [ ] Tema/Home: usare o rimuovere `useDockingOnMobile`
  - tipo: bug/app
  - priorita: low
  - obiettivo: eliminare impostazioni salvate ma non applicate

- [ ] Tema/Home: usare o rimuovere `showHomeReport`
  - tipo: bug/app
  - priorita: low
  - obiettivo: evitare preferenze UI esposte ma ignorate

## Audit esteso 4 - login, ai, build, configurazione

- [ ] Login: ridurre singleton globale `loginCode`
  - tipo: architettura/app
  - priorita: medium
  - obiettivo: rendere stato auth più testabile e meno accoppiato

- [ ] CalDAV login: validare/testare endpoint prima di salvare credenziali
  - tipo: bug/security
  - priorita: medium
  - obiettivo: evitare configurazioni salvate ma non funzionanti

- [ ] CalDAV storage: uniformare opzioni secure storage con `AppSettings`
  - tipo: bug/architettura
  - priorita: low
  - obiettivo: usare lo stesso standard di storage sicuro ovunque

- [ ] Build/CI: gestire dipendenze locali `../../report` e `../../ads_connector_flutter`
  - tipo: devops
  - priorita: medium
  - obiettivo: evitare build fragili fuori dalla struttura attuale del repository

- [ ] IA: non esporre Mistral finché `_callMistral` non è implementato
  - tipo: bug/app
  - priorita: high
  - obiettivo: evitare una scelta provider che finisce sempre in errore

- [ ] IA: completare o rimuovere Cohere da enum, settings e UI
  - tipo: bug/app
  - priorita: medium
  - obiettivo: allineare configurazione e runtime dei provider IA

- [ ] IA: aggiornare doc per spiegare quando un provider è supportato o solo dichiarato
  - tipo: documentazione
  - priorita: low
  - obiettivo: evitare che la UI prometta provider non realmente usabili

## Audit esteso - Dubbi e test

- [ ] Import CSV: non accettare righe con errori bloccanti
  - tipo: bug/app
  - priorita: high
  - obiettivo: bloccare l'import quando una riga ha errori che rendono il record non valido
  - perche: il dialogo potrebbe continuare anche con righe problematiche, rischiando dati parziali o incoerenti

- [ ] Conteggio righe CSV valide/non valide con piu errori per riga
  - tipo: bug/app
  - priorita: medium
  - obiettivo: contare correttamente le righe problematiche anche se una singola riga genera piu errori
  - perche: il riepilogo di import deve rappresentare i record, non il numero totale di singoli messaggi di errore

- [ ] Verificare mapping WooCommerce di "In primo piano?"
  - tipo: bug/app
  - priorita: low
  - obiettivo: confermare che il campo featured venga letto e scritto correttamente
  - perche: il mapping del flag potrebbe essere disallineato con la struttura reale di WooCommerce

- [ ] Cifrare davvero i dati smartcard
  - tipo: bug/security
  - priorita: high
  - obiettivo: sostituire Base64 con una protezione reale dei dati sensibili smartcard
  - perche: Base64 e solo codifica, non cifratura

- [ ] Non bypassare la validazione URL/HTTPS nel login smartcard
  - tipo: bug/security
  - priorita: high
  - obiettivo: impedire l'accesso se l'endpoint non e valido o non usa HTTPS quando richiesto
  - perche: il login non deve aggirare i controlli di sicurezza per comodita

- [ ] Encodare i parametri dinamici degli endpoint MGWS loyalty
  - tipo: bug/plugin
  - priorita: high
  - obiettivo: usare `Uri.encodeComponent` per card number ed email nei path loyalty
  - perche: caratteri speciali possono rompere la route o produrre lookup errati

- [ ] Esplicitare o implementare i placeholder RFID
  - tipo: bug/app
  - priorita: medium
  - obiettivo: decidere se i metodi RFID placeholder devono essere funzionali o dichiarati non supportati
  - perche: i placeholder attuali possono far sembrare disponibile una funzione che in realta non esiste

- [x] Correggere le URL dell'updater rotte dal refuso del nome del repository
  - tipo: bug/app
  - priorita: high
  - obiettivo: `lib/updater/updater_service.dart`, `lib/doc/installation.md` e il badge Obtainium in `README.md` puntano a `mgws-inventory`
  - perche: l'updater desktop deve leggere le release dal repository GitHub reale
  - stato: completato con la rinomina a `mgws_inventory`; API release verificata su `mgws-inventory`

- [ ] Decidere il destino di `lib/rfid/rfid_gui.dart`
  - tipo: manutenzione/app
  - priorita: medium
  - obiettivo: il widget `RFIDTestWidget` non e piu aperto da nessuna schermata dopo la rimozione della card RFID dalla home; decidere se spostarlo nella tab `Impostazioni > RFID` o se eliminarlo
  - perche: un file widgets non raggiungibile da nessuna schermata non e manutenibile e puo sembrare una funzione attiva
  - stato: la tab `Impostazioni > RFID` espone solo parametri di connessione e un test di connessione, non la scansione tag
  - verifica minima: ogni schermata RFID dichiarata in `lib/doc` e raggiungibile dall'utente, oppure il file viene rimosso

- [ ] Ripristinare `analysis_options.yaml`
  - tipo: manutenzione
  - priorita: medium
  - obiettivo: reintrodurre la configurazione di linting e analisi statica del progetto
  - perche: al momento la base di analisi non e esplicita nonostante `flutter_lints` sia presente

- [ ] Proteggere `setState` asincroni con `mounted`
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare update UI dopo dispose nei flussi asincroni
  - perche: alcune inizializzazioni async possono completarsi dopo che il widget e stato smontato

- [x] Correggere `applicationId` e naming Linux/Windows se definitivo
  - tipo: devops
  - priorita: low
  - obiettivo: allineare i nomi di pacchetto/binario alla nomenclatura reale del progetto
  - perche: gli identificatori tecnici ora usano `it.mgws.mgws_inventory` e i nomi visibili/binari usano `mgws_inventory`

## Audit esteso 5 - ordini e coupon

- [ ] Ordini: riallineare dettaglio dopo cambio stato
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare pannello dettagli stale dopo aggiornamento stato ordine

- [ ] Ordini: evitare crash con `ordine.id!`
  - tipo: bug/app
  - priorita: high
  - obiettivo: rimuovere assunzioni non sicure su ID nullable

- [ ] Ordini: usare davvero checkbox `Nota visibile al cliente`
  - tipo: bug/app
  - priorita: medium
  - obiettivo: passare la scelta del dialog al metodo di salvataggio nota

- [ ] Ordini: correggere calcolo subtotale
  - tipo: bug/app
  - priorita: high
  - obiettivo: calcolare correttamente totale meno spedizione e tasse

- [ ] Ordini: completare flusso creazione ordine con prodotti
  - tipo: bug/app
  - priorita: low
  - obiettivo: evitare creazione di ordini vuoti o incompleti
  - stato: per ora gli ordini si leggono soltanto; il pulsante `Nuovo ordine` e' nascosto dietro il flag di build `ORDER_CREATE` (default `false`) in `lib/orders/order_list/order_list.gui.dart`, il codice di `lib/orders/order_editor/` resta
  - verifica minima: prima di riattivare il flag, un ordine creato dall'app ha prodotti, quantita e totali corretti in WooCommerce

- [ ] Coupon: non simulare sempre validazione positiva
  - tipo: bug/app
  - priorita: high
  - obiettivo: mostrare il vero esito di validazione coupon

- [ ] Coupon: usare i validator reali nel form
  - tipo: bug/app
  - priorita: high
  - obiettivo: far rispettare formati, limiti importo, date e percentuali

- [ ] Sconto: mostrare data e orario alla creazione
  - tipo: idea/app
  - priorita: medium
  - obiettivo: quando si crea uno sconto (coupon), mostrare in creazione anche data e orario
  - perche: l'utente vuole sapere subito quando lo sconto viene creato, non solo la data di scadenza
  - verifica minima: creando uno sconto compare data e orario di creazione nel form o nel riepilogo

- [ ] Coupon: chiarire accesso diretto WooCommerce vs gateway condiviso
  - tipo: architettura/app-plugin
  - priorita: medium
  - obiettivo: allineare il modulo coupon al pattern degli altri moduli backend

## Audit esteso 6 - backend query e sicurezza

- [ ] JWT: supportare token root response per `jwt-auth/v1/token`
  - tipo: bug/app
  - priorita: high
  - obiettivo: non fallire se la risposta usa `token` fuori da `data`

- [ ] JWT: gestire HTTP 403 non JSON
  - tipo: bug/app
  - priorita: medium
  - obiettivo: mostrare errore reale invece di un parsing failure generico

- [ ] JWT: non loggare `error.response?.data` completo
  - tipo: bug/security
  - priorita: high
  - obiettivo: evitare leak di dati sensibili nei log


- [ ] Woo API key/secret: chiarire persistenza e auto-connect
  - tipo: architettura/app
  - priorita: medium
  - obiettivo: definire se la modalità API e' davvero supportata come alternativa persistente

- [ ] SecureStorage: evitare `deleteAll()` globale per logout/reset sessione
  - tipo: bug/app
  - priorita: medium
  - obiettivo: non cancellare segreti di altri moduli per errore

- [ ] URL validator: coprire range IP locali/riservati mancanti
  - tipo: bug/security
  - priorita: high
  - obiettivo: ridurre bypass e SSRF in validazione URL

- [ ] Woo prodotti/varianti: ridurre log payload completi e body errore
  - tipo: bug/security
  - priorita: medium
  - obiettivo: non stampare dati operativi sensibili nei log

- [ ] Woo batch delete: verificare payload `{id, force}` compatibile
  - tipo: bug/app
  - priorita: medium
  - obiettivo: confermare compatibilita con API batch WooCommerce

- [ ] Woo media: validare URL remoto in `uploadFromUrl`
  - tipo: bug/security
  - priorita: high
  - obiettivo: evitare URL arbitrari verso backend senza controllo


- [ ] Woo categorie: correggere `getEmptyCategories()`
  - tipo: bug/app
  - priorita: low
  - obiettivo: allineare nome metodo e risultato effettivo

- [ ] WordPress utenti: validare input creazione App Password e Woo API Key
  - tipo: bug/app
  - priorita: medium
  - obiettivo: filtrare valori vuoti o permessi non ammessi prima dell'invio

- [ ] PlatformManager: chiarire `setPlatform()` e `reset()` no-op
  - tipo: architettura/app
  - priorita: low
  - obiettivo: evitare chiamate che sembrano operative ma non lo sono

## Audit esteso 7 - prodotti crea, immagini, QR, custom fields

- [ ] Nuovo prodotto: mostrare errore inizializzazione invece di ignorarlo
  - tipo: bug/app
  - priorita: medium
  - obiettivo: non nascondere fallimenti di bootstrap della schermata

- [ ] Nuovo prodotto: validare prezzi con formato locale
  - tipo: bug/app
  - priorita: high
  - obiettivo: evitare conversioni silenziose a 0.0

- [ ] Nuovo prodotto: validare quantità/prezzo varianti
  - tipo: bug/app
  - priorita: high
  - obiettivo: prevenire valori invalidi o negativi nelle varianti

- [ ] Nuovo prodotto: duplicazione variante non deve copiare barcode/barcode interno rischiosi
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare duplicati reali nel gestionale o in WooCommerce

- [ ] Nuovo prodotto: verifica post-salvataggio varianti non deve basarsi solo su barcode interno/conteggio
  - tipo: bug/app
  - priorita: medium
  - obiettivo: riconoscere meglio mancanze o collisioni di varianti


- [ ] Woo custom fields: verificare uso `custom_fields` vs `meta_data`
  - tipo: bug/app
  - priorita: medium
  - obiettivo: allineare la forma dei dati alle API WooCommerce reali

- [ ] Woo custom fields: mostrare errore se update ritorna `false`
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare fallimenti silenziosi del salvataggio

- [ ] Searchable checkbox dialog: deduplica case-insensitive
  - tipo: bug/app
  - priorita: low
  - obiettivo: evitare valori duplicati con differenze di maiuscole/minuscole

## Audit esteso 8 - native config e release


- [ ] Android/iOS: verificare permessi dichiarati e motivazioni
  - tipo: devops
  - priorita: medium
  - obiettivo: allineare i permessi dichiarati con il reale uso delle funzionalita
  - stato Android: permessi Bluetooth rimossi finche lo scanner RFID resta in alpha; restano rete, camera e NFC per funzioni effettivamente collegate
  - resta: completare verifica iOS e rivalutare Bluetooth quando RFID uscira dalla alpha

- [ ] Windows metadata: rimuovere `com.example` e typo `abigliamento`
  - tipo: devops
  - priorita: low
  - obiettivo: rendere i metadati desktop coerenti col progetto

- [ ] Linux/Windows: completare naming package/binario
  - tipo: devops
  - priorita: low
  - obiettivo: uniformare i nomi di build desktop

## Conformita' fiscale e registratore telematico

- [ ] Verificare in app lo storico scontrini letto da MGWS dopo una reinstallazione
  - tipo: test/app
  - priorita: medium
  - obiettivo: confermare dall'interfaccia che storico, turno aperto, chiusure, progressivo e residuo rendibile arrivano dal server
  - stato: `StoricoCassaStore` e i contatori locali sono stati rimossi; l'app legge tutto da `GET /pos/receipts`, `GET /pos/shifts` e `/pos/closings` (plugin schema 11, tipi documento normalizzati). Endpoint, residuo e reso oltre il limite sono provati sul WordPress locale con i payload generati dall'app, ma non con la GUI
  - nota: i dati rimasti in SharedPreferences (`storico_cassa_*`, `cassa_metriche_*`) sui dispositivi gia' in uso non vengono piu' letti ne' migrati; le chiusure registrate solo in locale prima di questa versione non compaiono nello storico
  - verifica minima: su un dispositivo appena installato, collegato al WordPress locale, aprire turno, vendere, fare un reso parziale e chiudere il turno; poi reinstallare e ritrovare storico, chiusura, progressivo e residuo corretto della riga resa

- [ ] Trovare l'adapter corretto per il registratore telematico
  - tipo: ricerca/app
  - priorita: medium
  - obiettivo: scegliere e integrare il modo corretto per pilotare il registratore di cassa dall'app, dietro l'interfaccia con modalita' simulazione gia' prevista
  - perche: non esiste un protocollo univoco per i registratori telematici e ogni produttore espone API o protocolli propri (Epson, RCH, Custom, Ditron, Axon); senza il dispositivo non e possibile scegliere, quindi la voce resta aperta
  - riferimento: la localizzazione italiana di Odoo tratta la stampante/registratore come adapter per produttore, con modalita' simulazione come funzionalita' di prima classe e senza driver universale; il trasporto usato e' HTTPS in rete locale, non seriale USB (Epson ePOS richiede certificato self-signed)
  - nota: non e' un adempimento fiscale. Il collegamento POS-registratore e' amministrativo e si fa una volta sola nel portale "Fatture e Corrispettivi" (Provvedimento del 31 ottobre 2025, guida operativa Agenzia delle Entrate); l'app deve solo esporre l'identificativo POS, gia' fatto, e registrare il metodo di pagamento per corrispettivo, gia' fatto nel checkout
  - nota: `usb_serial` e Android-only, quindi non e una base per il desktop; la gestione corrente e l'interfaccia con modalita' simulazione
  - verifica minima: scelto il produttore, adapter implementato dietro l'interfaccia e verificato sull'hardware reale, con la modalita' simulazione ancora funzionante in assenza di dispositivo

- [ ] Documentare la procedura di abbinamento POS-registratore per l'esercente
  - tipo: documentazione/app
  - priorita: medium
  - obiettivo: spiegare nelle impostazioni e in `lib/doc` come usare l'identificativo POS nel portale "Fatture e Corrispettivi", e cosa fare quando si rigenera il codice
  - perche: l'obbligo di collegamento e' in vigore dal 1 gennaio 2026 e l'abbinamento va fatto dal commerciante, non dall'app; senza istruzioni l'esercente non sa che cosa abbinare ne quando rifarlo
  - dettagli: finestre temporali per i POS attivati dopo febbraio 2026 (dal 6' all'ultimo giorno del secondo mese successivo), abbinamento multiplo consentito, esclusioni per vending, carburante e ricarica veicoli elettrici, e procedura web "Documento Commerciale on-line" come alternativa al registratore
  - verifica minima: un esercente puo' eseguire l'abbinamento leggendo solo la schermata impostazioni e la documentazione, senza assistenza

## ERP commerciale 
-tutto quello che serve per rendelo un prodtto commerciale finito

Contesto 2026-09-19: confronto con `test_altri_programmi/VetrinaDigitale` (C# WinForms + SQL Server: prodotti/marche/categorie/generi, varianti taglia/colore/qta, clienti/citta, scontrini/righe/metodi pagamento, resi su riga, ordini fornitori). L'app Flutter + MGWS + WooCommerce e gia oltre su POS, inventario, loyalty, dashboard, import/export, RFID/QR. Questa sezione elenca solo funzionalita per renderlo davvero commerciale come ERP/SAP. Nessuna voce qui va in `lib/doc` finche non e implementata.

- [ ] ERP POS: turno cassa, fondo, versamenti/prelievi, chiusura con differenze
  - tipo: app/plugin/UI
  - priorita: high
  - obiettivo: apertura turno, fondo iniziale, totali per metodo, rimborsi, contante reale vs atteso, note operatore, stampa/export chiusura
  - perche: senza riconciliazione cassa non e vendibile a negozi reali
  - grafica app: apertura turno, riepilogo giornaliero, form chiusura, differenze evidenziate
  - verifica minima: turno raccoglie vendite/resi e genera chiusura coerente

- [ ] ERP documenti B2B: preventivi, DDT, fatture, note credito
  - tipo: app/plugin/UI
  - priorita: high
  - obiettivo: ciclo preventivo -> ordine cliente -> DDT -> fattura/nota credito, numerazioni separate, PDF/stampa
  - perche: scontrino da solo non copre B2B e resi fornitore/cliente formali
  - verifica minima: documento emesso con numero progressivo, righe, IVA, totale e PDF

- [ ] ERP magazzino: multi-sede, ubicazioni autoritative, lotti/scadenza/matricole
  - tipo: app/plugin/UI
  - priorita: high
  - obiettivo: magazzini multipli, ubicazioni magazzino/stanza/scaffale/ripiano vincolanti, lotto/scadenza/matricola per variante, giacenza per lotto
  - perche: stock globale singolo non basta per ERP reale e moda con riassortimenti
  - verifica minima: stesso barcode interno in due magazzini/lotti ha giacenze separate e movimenti distinti

- [ ] ERP acquisti: RdA, listini fornitore, ricezione parziale, reso a fornitore, backorder
  - tipo: app/plugin/UI
  - priorita: high
  - obiettivo: richiesta acquisto -> ordine -> ricezione parziale/totale -> reso fornitore; prezzo acquisto, sconto, costi accessori; costo medio ponderato e ultimo costo
  - perche: ordine semplice + carico non traccia costi, backorder e marginalita reale
  - verifica minima: ricezione parziale lascia backorder aperto e aggiorna costo medio

- [ ] ERP moda: matrici taglie/colori, collezioni/stagioni, reparti, anagrafiche controllate
  - tipo: app/plugin/UI
  - priorita: high
  - obiettivo: tabelle taglie, colori, reparti, stagioni, marche controllate no-duplicati; matrice taglia/colore in creazione prodotto; soft-delete/blocco se usate
  - perche: categorie/tag Woo liberi generano duplicati operativi tipo `MARCHE/CATEGORIE/GENERI/TAGLIE/COLORI/CITTA` di VetrinaDigitale
  - verifica minima: anagrafica usata non eliminabile; matrice crea solo varianti valide

- [ ] ERP clienti/CRM: B2C/B2B, P.IVA/CF/SDI, indirizzi multipli, consensi GDPR
  - tipo: app/plugin/UI
  - priorita: high
  - obiettivo: chiarire Woo vs MGWS gestionale; anagrafiche con P.IVA/CF/SDI, indirizzi spedizione/fatturazione, segmenti, consensi privacy, export
  - perche: email/telefono/citta singola non bastano per fatturazione e marketing
  - verifica minima: cliente B2B fatturabile con SDI; consenso revocabile tracciato

- [ ] ERP contabilita IT: prima nota, IVA, scadenziario, fatturazione elettronica SDI
  - tipo: app/plugin/UI
  - priorita: high
  - obiettivo: prima nota, aliquote IVA, scadenziario clienti/fornitori, pagamenti parziali/insoluti/solleciti, XML/PEC/SDI, corrispettivi telematici, conservazione
  - perche: senza SDI/corrispettivi non e commerciale in Italia
  - verifica minima: fattura genera XML valido; scadenza pagata parzialmente resta aperta per il residuo

- [ ] ERP tesoreria: cassa/banche, riconciliazione, multi-metodo e multi-valuta
  - tipo: app/plugin/UI
  - priorita: medium
  - obiettivo: conti cassa/banca, movimenti dare/avere, riconciliazione estratto conto, metodi pagamento come in `METODI_PAGAMENTO`, listini multi-valuta
  - perche: totali POS senza tesoreria non quadrano con banca
  - verifica minima: incasso POS quadra con movimento tesoreria e riconciliazione

- [ ] ERP HR: dipendenti reali MGWS, turni/presenze, provvigioni, ruoli/audit
  - tipo: app/plugin/sicurezza/UI
  - priorita: high
  - obiettivo: sostituire mock dipendenti con backend MGWS; turni, presenze, permessi, provvigioni per commesso/vendita; ruoli granulari; audit chi/cosa/quando
  - perche: multi-operatore senza permessi e audit non e vendibile
  - verifica minima: commesso vede solo funzioni abilitate; ogni vendita/movimento registra operatore

- [ ] ERP logistica: packing, spedizioni, corrieri, packing-list
  - tipo: app/plugin/UI
  - priorita: medium
  - obiettivo: preparazione ordini, colli, pesi, etichette corriere, tracking, DDT da spedizione
  - perche: ordini Woo senza evasione restano solo amministrativi
  - verifica minima: ordine evaso genera colli, tracking e DDT collegati

- [ ] ERP promozioni: saldi, bundle, gift-card, prezzi per cliente/canale
  - tipo: app/plugin/UI
  - priorita: medium
  - obiettivo: listini multipli, promo a periodo, bundle taglia/colore, gift-card con saldo, prezzi B2B/B2C/e-commerce/negozio
  - perche: coupon singolo non copre saldi moda e B2B
  - verifica minima: promo attiva solo nel periodo e sul canale corretto; gift-card scala saldo

- [ ] ERP BI: KPI margini/rotazione/sell-through, giacenza valorizzata, report schedulati
  - tipo: app/plugin/report/UI
  - priorita: high
  - obiettivo: venduto, margine, rotazione, top/worst, sell-through collezione, scontrino medio, resi per motivo, giacenza valorizzata a costo medio; export PDF/CSV; invii schedulati
  - perche: fatturato senza margine e rotazione non guida acquisti
  - verifica minima: report con costo noto mostra margine coerente con vendite e movimenti

- [ ] ERP prodotto commerciale: licenze, onboarding, demo dataset, SLA/supporto
  - tipo: docs/process
  - priorita: medium
  - obiettivo: attivazione licenza, multi-azienda/negozio, setup guidato, dataset demo moda, manuale operativo, note release, canale supporto/SLA
  - perche: senza packaging commerciale resta progetto interno
  - verifica minima: nuova installazione parte da wizard con demo e licenza attiva

## To publish

Piano operativo per pubblicare MGWS Inventory come software libero (GPL-3.0) sostenuto da donazioni: GitHub e F-Droid, poi Google Play, il plugin MGWS su wordpress.org, la libreria `report_flutter` su pub.dev, comunicazione su Reddit e campagna Kickstarter. Ordine delle fasi: chiusura codice → (legale, pub.dev, plugin in parallelo) → release GitHub → donazioni → F-Droid → Google Play → comunicazione → Kickstarter. Kickstarter va per ultimo: le campagne software riescono quando esiste gia' un pubblico.

Gia' fatto (22 ottobre 2026): licenza GPL-3.0 con tab `Info` e licenze open source nell'app; consenso prima dell'invio di dati ai servizi IA cloud; nome "MGWS Inventory" su tutte le piattaforme; opzioni di build `DONATIONS` e `UPDATE_CHECK`; permessi macOS e predisposizione iOS; `report_flutter` da GitHub con versione `1.0.58+58`; `fastlane/` per F-Droid, `PRIVACY.md`, `CONTRIBUTING.md`, `SECURITY.md`; README e `lib/doc` in inglese con funzioni divise tra "solo app" e "con plugin MGWS"; cartelle e file rinominati in inglese; test rimossi; `report_flutter` pronta per pub.dev (dry-run pulito, 12 screenshot, schermate in inglese e italiano).

Gia' fatto (27 ottobre 2026): `report_flutter` pubblicata su pub.dev e usata dall'app come `^1.0.0` (lock da pub.dev, nessun override); release pubbliche fino a `v1.0.67` con installer/zip Windows, AppImage, Flatpak, APK e AAB; push su GitHub con `Flutter Build` verde; 8 screenshot dell'app in `fastlane/metadata/android/en-US/images/phoneScreenshots/` e nel README; ricetta F-Droid `fdroid/it.mgws.mgws_inventory.yml` con build riproducibile verificata, NonFreeNet e `Donate` Ko-fi; modelli issue in `.github/ISSUE_TEMPLATE/`; `.github/FUNDING.yml` con Ko-fi.

Decisioni prese: pulizia di `docker/` dalla cronologia del repo saltata; nessuna email di contatto per gli store (contatto = issue GitHub); iOS e App Store rimandati.

### Fase 1 - Chiusura del codice

- [ ] Finire la traduzione dei testi italiani scritti nel codice
  - tipo: app/l10n
  - priorita: high
  - obiettivo: completare la sessione "Localize remaining hard-coded Italian UI strings" modulo per modulo e controllarne i commit
  - perche: con l'app in inglese alcune schermate mostrano ancora testi italiani
  - verifica minima: nessuna stringa italiana visibile con lingua inglese; `flutter analyze` pulito

- [ ] Provare l'app completa sul WordPress locale
  - tipo: verifica/release
  - priorita: high
  - obiettivo: provare cassa, magazzino, stampa, tab `Info` e consenso IA sul WordPress locale prima della comunicazione pubblica
  - stato: push e `Flutter Build` verde fatti; la prova manuale completa non risulta registrata
  - verifica minima: nessun blocco nei flussi principali con dati di prova

- [ ] Configurare il repository GitHub
  - tipo: process
  - priorita: medium
  - obiettivo: attivare Private vulnerability reporting (Settings → Security), descrizione, topics (`flutter`, `woocommerce`, `pos`, `inventory`, `open-source`, `retail`), immagine social
  - stato: modelli issue gia' presenti; al 28 ottobre 2026 descrizione vuota, nessun topic, segnalazione privata disattivata
  - perche: il link in `SECURITY.md` non funziona finche' la segnalazione privata non e' attiva
  - verifica minima: "Report a vulnerability" visibile nella scheda Security

### Fase 2 - Aspetti legali, fiscali e licenza

- [ ] Decidere la clausola sugli app store in `CONTRIBUTING.md`
  - tipo: decisione/legale
  - priorita: medium
  - obiettivo: confermare o togliere il permesso aggiuntivo (GPL-3.0 sezione 7) che consente la distribuzione dei contributi esterni tramite App Store e Google Play
  - perche: senza, un contributo esterno puo' bloccare in futuro la pubblicazione su iOS
  - verifica minima: testo definitivo in `CONTRIBUTING.md`

- [ ] Consultare il commercialista su donazioni e Kickstarter
  - tipo: fiscale
  - priorita: high
  - obiettivo: trattamento fiscale di Ko-fi, Liberapay, GitHub Sponsors e fondi Kickstarter (prestazione occasionale o partita IVA forfettaria, IVA sulle ricompense come prevendita)
  - perche: e' l'unico punto che blocca insieme donazioni, Google Play (stato trader) e Kickstarter
  - verifica minima: modalita' di incasso e fatturazione decisa per iscritto

- [ ] Decidere lo stato "trader" per Google Play (DSA)
  - tipo: decisione/legale
  - priorita: medium
  - obiettivo: dichiarare se lo sviluppatore e' un trader secondo il Digital Services Act
  - perche: se trader, indirizzo e telefono diventano pubblici sulla scheda Play
  - verifica minima: dichiarazione compilata in Play Console

### Fase 3 - Libreria report_flutter su pub.dev

- [ ] Aggiornare `lib/doc/developer-guide.md` dopo il passaggio a pub.dev
  - tipo: documentazione
  - priorita: medium
  - obiettivo: la guida dice ancora che `report_flutter` e' fissata a un commit GitHub e passera' a pub.dev; l'app usa gia' `report_flutter: ^1.0.0` da pub.dev
  - verifica minima: la guida descrive la dipendenza pub.dev e come usare un override locale solo per sviluppare la libreria

### Fase 4 - Plugin MGWS su GitHub e wordpress.org

Repository: <https://github.com/Vincenzoferrara/mgws-inventory-wordpress-plugin>. Il plugin va pubblicato anche nella directory ufficiale di wordpress.org.

- [ ] Eseguire Plugin Check prima dell'invio
  - tipo: plugin/verifica
  - priorita: high
  - obiettivo: installare il plugin ufficiale "Plugin Check" su un WordPress di prova, analizzare lo zip della release e correggere quanto segnala
  - nota: revisione di sicurezza fatta il 22 ottobre 2026: nessun problema bloccante (permessi su tutte le 53 rotte REST, nonce e capability su tutti gli AJAX, SQL preparato); corretti input non sanitizzati, intestazione con licenza e URI, FAQ con link all'app
  - verifica minima: Plugin Check senza errori

- [ ] Inviare il plugin a wordpress.org
  - tipo: release
  - priorita: high
  - obiettivo: creare l'account wordpress.org, inviare lo zip dalla pagina "Add your plugin", rispondere ai revisori (di solito qualche settimana), poi pubblicare con SVN il codice in `trunk`, il tag della versione e le immagini in `assets/` (icona 256×256, banner 1544×500 e 772×250, screenshot)
  - verifica minima: plugin installabile da Bacheca → Plugin → Aggiungi nuovo

- [ ] Release del plugin su GitHub e collegamento con l'app
  - tipo: release/docs
  - priorita: medium
  - obiettivo: release GitHub con lo zip installabile; nel README del plugin il link all'app e la stessa divisione "solo app / con plugin"; nel README dell'app e in `lib/doc` il link alla pagina wordpress.org quando sara' online
  - verifica minima: da ogni README si arriva agli altri due progetti

### Fase 5 - Release su GitHub e Obtainium

- [ ] Fare un video demo dell'app
  - tipo: marketing/docs
  - priorita: medium
  - obiettivo: video di 1-2 minuti (cassa, prodotti, magazzino, stampa, dashboard) dal WordPress locale con dati di prova, per Reddit e Kickstarter
  - perche: gli screenshot ci sono gia', il video no
  - verifica minima: video linkato nel README

### Fase 6 - Donazioni

- [ ] Aprire Liberapay e GitHub Sponsors
  - tipo: process
  - priorita: medium
  - obiettivo: aggiungere ai Ko-fi esistenti Liberapay (molto usato nel mondo FOSS e da F-Droid) e GitHub Sponsors
  - verifica minima: profili attivi e collegati al conto

- [ ] Collegare gli account donazioni ovunque
  - tipo: app/docs
  - priorita: medium
  - obiettivo: `.github/FUNDING.yml`, README di app, plugin e libreria, campi `Donate`/`Liberapay` di F-Droid, tab `Info`
  - nota: nelle build per Google Play e App Store niente link alle donazioni dentro l'app (`DONATIONS=false`)
  - verifica minima: pulsante "Sponsor" visibile su GitHub

### Fase 7 - F-Droid

- [ ] Inviare la merge request a fdroiddata
  - tipo: release
  - priorita: high
  - obiettivo: account gitlab.com, merge request a `fdroid/fdroiddata`, risposte ai revisori; facoltativo: build riproducibili per pubblicare con la propria firma
  - stato: ricetta `fdroid/it.mgws.mgws_inventory.yml` pronta, `fdroid build` locale riuscito il 27 ottobre 2026 su `1.0.66`; l'ultima release e' `v1.0.67`, valutare se aggiornare la ricetta prima dell'invio; testo MR in `../fdroid-test/mr-description.md`
  - verifica minima: app su <https://f-droid.org/packages/it.mgws.mgws_inventory/>

- [ ] Fare il backup sicuro della chiave di firma Android
  - tipo: sicurezza
  - priorita: high
  - obiettivo: copia cifrata fuori dal computer di `android/keystore/` e della password
  - perche: senza la chiave non si puo' piu' aggiornare l'app su Play ne', con build riproducibili, su F-Droid
  - verifica minima: backup ripristinato con successo su un'altra macchina

### Fase 8 - Google Play

- [ ] Aprire l'account sviluppatore Google Play
  - tipo: process
  - priorita: medium
  - obiettivo: account (25 $ una tantum), verifica dell'identita', stato trader (fase 2)
  - verifica minima: Play Console accessibile

- [ ] Preparare la build e la scheda per Google Play
  - tipo: release
  - priorita: medium
  - obiettivo: AAB con `--dart-define=DONATIONS=false --dart-define=UPDATE_CHECK=false`; testi (riusare quelli F-Droid), screenshot, icona 512, immagine in evidenza 1024×500; modulo Sicurezza dei dati (nessun dato raccolto dallo sviluppatore, dati verso il sito dell'utente e facoltativamente i provider IA); URL privacy <https://github.com/Vincenzoferrara/mgws-inventory/blob/master/PRIVACY.md>; classificazione dei contenuti; giustificare il traffico HTTP in chiaro (WordPress in LAN) o limitarlo con `network_security_config`
  - verifica minima: scheda completa senza avvisi in Play Console

- [ ] Preparare un sito WordPress demo per i revisori
  - tipo: infrastruttura
  - priorita: high
  - obiettivo: WordPress con WooCommerce, MGWS, dati finti e credenziali di prova da indicare nella revisione
  - perche: senza backend l'app non mostra nulla e viene rifiutata
  - verifica minima: login dall'app con le credenziali di prova su una rete esterna

- [ ] Completare il test chiuso obbligatorio
  - tipo: release
  - priorita: high
  - obiettivo: almeno 12 tester per 14 giorni consecutivi (regola per i nuovi account personali), poi richiesta di accesso alla produzione
  - verifica minima: app pubblicata in produzione

### Fase 9 - Comunicazione e Reddit

- [ ] Preparare il post di presentazione
  - tipo: marketing
  - priorita: medium
  - obiettivo: testo in inglese (problema → soluzione → open source → cosa fa senza e con il plugin → link), screenshot e video; facoltativa una pagina web semplice su GitHub Pages
  - verifica minima: bozza approvata

- [ ] Pubblicare su Reddit e nelle comunita'
  - tipo: marketing
  - priorita: medium
  - obiettivo: un subreddit alla volta, a qualche giorno di distanza, leggendo prima le regole sull'autopromozione: r/selfhosted (dati sul proprio server), r/opensource e r/coolgithubprojects (cerco contributori), r/woocommerce e r/Wordpress (app + plugin), r/FlutterDev (app + libreria), r/smallbusiness e r/retail (taglio pratico), r/fdroid (dopo F-Droid); forum e gruppi italiani di commercianti e WooCommerce; Mastodon
  - regole: rispondere ai commenti, non copiare lo stesso testo ovunque, non chiedere soldi nei primi post, portare i feedback nelle issue
  - verifica minima: feedback raccolti come issue su GitHub

### Fase 10 - Kickstarter

Regole verificate su <https://www.kickstarter.com/rules>: si puo' fare se la campagna finanzia qualcosa di nuovo. Il vecchio divieto su "e-commerce e strumenti gestionali" non esiste piu'.

- [ ] Decidere obiettivo, cifra e durata della campagna
  - tipo: decisione
  - priorita: medium
  - obiettivo: una funzione nuova e concreta da finanziare (candidato naturale: supporto a Shopify; in alternativa app iOS o driver per i registratori fiscali); cifra = ore di lavoro × tariffa + 5% Kickstarter + ~5% pagamenti + tasse + ricompense fisiche + margine; durata 30 giorni
  - perche: Kickstarter non ammette campagne per un prodotto gia' esistente e gratuito
  - verifica minima: obiettivo e cifra approvati anche dal commercialista

- [ ] Preparare la campagna nel rispetto delle regole
  - tipo: marketing/legale
  - priorita: medium
  - obiettivo: ricompense nuove e create dal progetto (accesso anticipato alle nuove funzioni, nome nei ringraziamenti della tab `Info`, pacchetti di modelli di etichette, gadget disegnati da te, voto sulla roadmap; non l'app gia' gratuita); niente servizi come cuore del progetto, niente quote o partecipazioni agli utili, niente rimandi a Ko-fi o altre piattaforme nella pagina; dichiarazione obbligatoria sull'IA (funzioni IA nell'app con chiave dell'utente e consenso, eventuale uso di assistenti IA nello sviluppo, contributo umano chiaro); mostrare solo funzioni che esistono davvero
  - requisiti: maggiorenne, residente in Italia, documento italiano, conto bancario italiano; beneficenza facoltativa fino al 10% se dichiarata prima del lancio
  - verifica minima: progetto approvato dalla revisione di Kickstarter

- [ ] Lanciare e seguire la campagna
  - tipo: marketing
  - priorita: medium
  - obiettivo: da 6 a 4 settimane prima testi, video, grafica e pagina "in arrivo"; da 4 a 1 settimana prima annunci su Reddit, GitHub, F-Droid e README verso la pagina "in arrivo"; lancio martedi' o mercoledi' mattina (ora USA); aggiornamenti settimanali durante i 30 giorni; dopo, sviluppo della funzione finanziata e consegna delle ricompense
  - verifica minima: campagna conclusa e ricompense consegnate

### Fase 11 - Dopo il lancio

- [ ] Gestire issue e release con regolarita'
  - tipo: process
  - priorita: medium
  - obiettivo: risposta alle issue entro la settimana con etichette `bug`, `enhancement`, `good first issue`; una release ogni 2-4 settimane con tag e versione del `pubspec.yaml` allineati; changelog in `fastlane/metadata/android/*/changelogs/<versionCode>.txt`; `lib/doc` aggiornata insieme al codice; ringraziamenti a donatori e sostenitori
  - verifica minima: nessuna issue senza risposta da piu' di una settimana

### Rimandati

- iOS e App Store: account Apple (99 €/anno), risposta sulla crittografia (`ITSAppUsesNonExemptEncryption`), privacy manifest, revisione Apple, nessun link esterno per donazioni.
