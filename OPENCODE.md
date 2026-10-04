# OPENCODE Local Routing

1 la  to do list delle cose da fare (sel al chiedo) si trvoa in todo.md
4. Se non e esplicitamente richiesto, o non serve, non leggere la cartella `docker`, dato che questa codebase e un'app Flutter.
5. Per ogni implementazione, fare domande finche non sei sicuro al 95% di cio che l'utente vuole e di come lo vuole.
6. Questo progetto Flutter e parte dello stesso sistema del plugin WordPress proprietario `MG-Warehouse-Stock-plugin-wordpress` in:
   - `../MG-Warehouse-Stock-plugin-wordpress`
7. Per integrazioni WordPress, l'app deve considerare validi solo due provider esterni: `MGWS` e `WooCommerce` o wordpress. L'app non deve parlare direttamente con `ATUM`, `myCred` o altri plugin WordPress terzi; se quelle funzioni servono, devono passare da `MGWS`.
8. `MGWS` e il plugin principale devono diventare completi: stock, inventario, movimenti, punti fedelta, clienti, report, fornitori e riordini devono essere nativi in `MGWS` oppure esposti da `MGWS` come gateway verso plugin esterni opzionali.
9. Se un'installazione preferisce usare plugin esterni come `ATUM` o `myCred`, la scelta deve restare interna a `MGWS`; l'app Flutter non deve conoscere quei plugin.
10. A ogni modifica funzionale al progetto, aggiornare sempre la documentazione in `lib/doc`. Questo vale quando si aggiunge, rimuove o modifica un'impostazione, un pulsante, una schermata, una classe, una funzione, un flusso utente, un'integrazione o qualsiasi comportamento dell'app. La documentazione deve descrivere solo l'utilizzo reale e attuale: non inserire confronti "prima/ora", changelog, note di versione o spiegazioni storiche. Aggiornare il file piu adatto tra quelli presenti in `lib/doc`, ad esempio `user-guide.md`, `configuration.md`, `developer-guide.md`, `modules-map.md`, `operational-flows.md`, `integrations.md` o altri file pertinenti.

11. Quando si creano commit, usare questo formato nel messaggio:
   - prima riga: titolo breve del commit
   - riga vuota
   - righe successive: descrizioni brevi, una per riga, ciascuna che inizia con `-`
   - **non fare commit senza che l'utente lo chieda esplicitamente**: anche a lavoro finito, lascia le modifiche non committate e attendi. Vale anche per il plugin WordPress e per la cartella `docker/`.
- (i commit devno essere in inglese)

12. `lib/doc` e la documentazione tecnica attuale del codice, utile a contributor e IA; non deve contenere backlog o analisi storiche.
13. Quando una task viene completata, se restano dubbi, rischi o follow-up, aggiungerli come nuove voci in `todo.md`. 
14. Prima di fare qualsiasi cosa sul progetto, leggere `lib/doc/architecture.md` e rispettare le regole architetturali li descritte.
15. Tutte le modifiche alla cartella `docker/` (core WordPress, plugin, temi, runbook, ecc.) devono essere inviate in un unico commit dal titolo `docker wordpress update`, senza spezzarle in piu commit con titoli diversi.
16. non creare test se non espressamte richiesto.


## Regole di lingua e traduzione
17. Ogni stringa visibile all'utente deve essere tradotta e letta da `context.l10n.<chiave>`. Non hardcodare testo destinato a schermate, pulsanti, etichette, tooltip, dialoghi, snackbar, validator, intestazioni di tabella o stati vuoti. Le chiavi stanno in `lib/traduzioni/app_en.arb` (template, inglese) e `lib/traduzioni/app_it.arb` (italiano).
18. I messaggi di commit sono scritti in inglese. Titolo breve in inglese, riga vuota, righe successive che iniziano con `-`, come da regola 11.
19. **Tutto il codice è scritto in inglese**: nomi di file, cartelle, classi, funzioni, metodi, variabili, parametri, campi, enum, costanti, chiavi di dizionario e commenti. Sono vietati identificatori e commenti in italiano, anche parzialmente. Il codice esistente va rinominato man mano che si tocca, non lasciato in italiano per comodo: se un nome italiano si incontra in un file che stai modificando, va convertito in inglese in quel passaggio. Nomi non descrittivi come `i`, `s`, `tmp` o abbreviazioni ambigue sono vietati: il nome deve dire cosa contiene. Esistono due sole eccezioni, perche' cambiarle romperebbe i dati gia salvati o il protocollo: i valori delle stringhe che vengono persistite o inviate (stati, metodi di pagamento, ruoli, chiavi JSON verso WordPress, MGWS e WooCommerce) e i dati inseriti dagli utenti. L'eccezione riguarda il valore, non il nome: `String receiptStatus` e' corretto, `String stato` no. Le stringhe visibili all'utente vanno in `context.l10n.<chiave>` con la chiave inglese, come da regola 17.
20. I nomi degli attributi delle varianti prodotto sono in inglese: `size` e `color`. Per collegarli agli attributi gia presenti nel catalogo WooCommerce usa la mappa in `lib/traduzioni/mappa_attributi.dart` invece di rinominare gli slug esistenti, che romperebbe i dati gia salvati.
21. I nomi delle chiavi di traduzione sono in inglese, `camelCase`, prefissati dal modulo di appartenenza. `gen_l10n` accetta solo nomi di metodo Dart validi: niente punti, niente oggetti annidati.
22. Non tradurre i dati inseriti dagli utenti (nomi prodotto, clienti, fornitori, note) ne le chiavi di persistenza e i nomi dei campi del protocollo verso WooCommerce, MGWS e WordPress. Cambiarli romperebbe i dati gia salvati. Vale per i valori, non per i nomi: come da regola 19 il nome del campo resta in inglese anche quando il valore persistito e' italiano.
23. Tutto il codice di traduzione sta sotto `lib/traduzioni/`. Non creare file di traduzione, ARB o helper in altre cartelle del progetto.
24. Prima di chiudere una modifica che tocca stringhe visibili esegui `flutter gen-l10n` e `dart run lib/traduzioni/verifica_traduzioni.dart`. La CI esegue gli stessi controlli e blocca la pull request se una chiave nuova non ha una traduzione.
25. Per numeri, importi e date non usare formati fissi tipo `NumberFormat.currency(locale: 'it_IT')`: prendi la lingua dal contesto con `Localizations.localeOf(context)` cosi seguono la lingua scelta dall'utente.
