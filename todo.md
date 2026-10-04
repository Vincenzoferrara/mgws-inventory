# Todo

Backlog unico del progetto. Contiene idee, task e dubbi ancora aperti; ogni voce deve spiegare cosa va fatto, perché e come verificarlo. Se resta aperto qualcosa, va sempre aggiunto qui invece di lasciarlo nel log.

## Regole

- La documentazione tecnica attuale resta in `lib/doc`.
- Quando una voce viene implementata,  rimuoverla.

## Verifiche aperte repository Flutter

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

- [ ] Sistemare la suite `flutter test` dopo il push non verificato del 2026-09-29
  - tipo: test/regressione
  - priorita: high
  - obiettivo: riportare verde la suite Flutter dopo l'invio dei commit locali a GitHub
  - perche: il push e' stato fatto su richiesta esplicita saltando il gate dei test; la suite aveva fallimenti in `test/prodotti/product_visual_refresh_test.dart`, `test/prodotti/filters_bar_layout_test.dart` e `test/woo_variations_e2e_test.dart`
  - note: il test F-Droid `test/fdroid/barcode_scanner_fdroid_test.dart` e' stato committato insieme al passaggio a `flutter_zxing`; resta da verificare tutta la suite dopo il push saltato
  - note 2026-10-02: misurata 89 test verdi e 18 rossi, falliti soprattutto in `test/prodotti/filters_bar_layout_test.dart`; i fallimenti non dipendono dal guard del primo frame introdotto in `lib/main.dart`, perche quel file di test non importa `main.dart` ne `reuse_class/gui/viewport_guard.dart`
  - verifica minima: `flutter test` termina con esito positivo oppure i test live/e2e instabili vengono separati dal gate ordinario con una scelta documentata

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

- [ ] Clienti: caricare oltre la prima pagina WooCommerce
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare che ricerca e statistiche si fermino ai primi 100 clienti

- [ ] Clienti: esporre o rimuovere CRUD non collegato alla UI
  - tipo: bug/app
  - priorita: medium
  - obiettivo: allineare controller e schermata clienti, evitando metodi mai usati o funzioni non accessibili

- [ ] Chiarire clienti WooCommerce vs clienti gestionali MGWS
  - tipo: architettura/app-plugin
  - priorita: high
  - obiettivo: definire se il dominio clienti resta WooCommerce diretto o se serve un gateway MGWS dedicato per dati gestionali aggiuntivi

- [ ] Utenti: caricare oltre i primi 20 record
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare che la lista utenti sia limitata al default WooCommerce/WordPress

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

- [ ] Ordini: caricare oltre i primi 100 ordini
  - tipo: bug/app
  - priorita: high
  - obiettivo: evitare che lista, statistiche e totali vendite restino limitati alla prima pagina di WooCommerce

- [ ] Ordini: statistiche calcolate solo sulla pagina caricata
  - tipo: bug/app
  - priorita: high
  - obiettivo: non falsare conteggi stato e totale vendite quando gli ordini superano la pagina caricata

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
  - priorita: high
  - obiettivo: evitare creazione di ordini vuoti o incompleti

- [ ] Coupon: aggiungere paginazione reale
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare liste tronche e rendere navigabile l'archivio coupon

- [ ] Coupon: aggiungere debounce e protezione race alla ricerca
  - tipo: bug/app
  - priorita: medium
  - obiettivo: evitare risultati fuori ordine durante il typing rapido

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

- [ ] Portare lo storico scontrini su MGWS e rimuovere `StoricoCassaStore`
  - tipo: app/plugin/UI
  - priorita: high
  - obiettivo: scontrini, chiusure e progressivo su MGWS come unica fonte, con lettura dello storico da server invece che da SharedPreferences
  - perche: il progressivo e' gia' assegnato dal server e salvato in `mg_pos_receipts`, ma lo storico completo resta in `storico_cassa_scontrini_pos_v1` su SharedPreferences; se il dispositivo si rompe o l'app viene reinstallata, righe, resi e chiusure di quel giorno spariscono e il backup WordPress non le ripristina, perche' non sono nel database
  - dipendenze: le tabelle `mg_pos_sales` e `mg_pos_sale_lines` e gli endpoint `GET /pos/sales` e `GET /pos/sales/{receipt_key}` sono gia' stati definiti nel design ma non implementati; `mg_pos_receipts` copre solo l'intestazione del documento
  - impatti: `validaReso` e `cercaPerId` in `cassa.code.dart` leggono lo store locale, quindi il residuo rendibile per linea deve diventare calcolabile dal server; `totaliGiornata` in `storico_cassa.code.dart` deve diventare la sintesi di `GET /pos/sales`; `cassa_metrics.dart` deriva i suoi otto contatori dagli scontrini server e i contatori locali si eliminano
  - nota: `architecture.md:80` impone gia' che i dati condivisi persistenti passino da WordPress/MGWS, quindi questa voce allinea il codice a una regola gia' scritta
  - verifica minima: dopo reinstall dell'app su un dispositivo nuovo lo storico scontrini, le chiusure e il progressivo sono completi e il residuo rendibile di una linea restituita e' corretto

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
