# Privacy policy

**MGWS Inventory** · last update: 22 October 2026 · [Italiano](#informativa-privacy)

MGWS Inventory is free and open source software (GPL-3.0). It is developed
by Vincenzo Ferrara. The developer runs no server
for the app and **receives no data** from it: no account, no analytics, no
tracking, no ads.

## Where your data goes

- **Your WordPress and WooCommerce site.** Products, orders, customers,
  loyalty cards, employees, suppliers, stock and print templates are read
  from and written to the site that you configure. That site, and whoever
  runs it, is the data controller for that data.
- **This device.** Login credentials and API keys are kept in the
  operating system's secure storage (Keychain, Keystore, libsecret or the
  Windows Credential Manager). Settings and the local cash register
  history are kept in the app's own storage. Logging out removes the
  credentials; uninstalling removes the app storage (on iOS the
  Keychain can keep the credentials until you log out).
- **AI services, only if you enable them.** When you ask for a product
  description, categories or tags, the app sends the product name,
  category, price, internal barcode and description to the provider that
  you chose (OpenAI, Anthropic, Google or Mistral), with **your own** API
  key. The app asks for your consent before the first use of each
  provider. No customer data is sent. Ollama runs on your own computer or
  server and sends nothing outside.
- **CalDAV, only if you configure it.** Calendar data is exchanged with
  the CalDAV server that you enter.
- **Update check.** On Windows, Linux and Android builds from GitHub, the
  app asks `api.github.com` for the latest release. GitHub sees your IP
  address, as for any web request. Store and F-Droid builds do not check.

## Permissions

| Permission | Why |
|------------|-----|
| Internet, network state | Connect to your WordPress site |
| Camera | Scan barcodes and QR codes; images are not stored or sent |
| NFC | Read and write staff login cards |
| Photos and files | Choose product images and import or export files |
| Local network (iOS) | Reach a WordPress site on your local network |

## Your rights

The developer holds no personal data about you or your customers. For data
stored on your WordPress site, contact whoever runs that site. For data
sent to an AI provider, see that provider's privacy policy.

## Contact

Questions: [GitHub issues](https://github.com/Vincenzoferrara/mgws-inventory/issues).

---

# Informativa privacy

**MGWS Inventory** · ultimo aggiornamento: 22 ottobre 2026

MGWS Inventory è software libero e open source (GPL-3.0), sviluppato da
Vincenzo Ferrara. Lo sviluppatore non gestisce
server per l'app e **non riceve alcun dato**: nessun account, nessuna
statistica, nessun tracciamento, nessuna pubblicità.

## Dove vanno i tuoi dati

- **Il tuo sito WordPress e WooCommerce.** Prodotti, ordini, clienti,
  carte fedeltà, dipendenti, fornitori, magazzino e modelli di stampa
  vengono letti e scritti sul sito che configuri. Il titolare del
  trattamento di questi dati è chi gestisce il sito.
- **Questo dispositivo.** Credenziali e chiavi API stanno nell'archivio
  sicuro del sistema operativo (Keychain, Keystore, libsecret o Gestione
  credenziali di Windows). Impostazioni e storico locale della cassa
  stanno nella memoria dell'app. Il logout cancella le credenziali; la
  disinstallazione cancella la memoria dell'app (su iOS il Keychain può
  conservare le credenziali finché non fai logout).
- **Servizi IA, solo se li attivi.** Quando chiedi una descrizione, delle
  categorie o dei tag, l'app invia nome, categoria, prezzo, barcode
  interno e descrizione del prodotto al provider scelto (OpenAI,
  Anthropic, Google o Mistral), con la **tua** chiave API. Prima del primo
  uso di ogni provider l'app chiede il consenso. Non vengono inviati dati
  dei clienti. Ollama gira sul tuo computer o server e non invia nulla
  all'esterno.
- **CalDAV, solo se lo configuri.** I dati del calendario vengono
  scambiati con il server CalDAV che indichi.
- **Controllo aggiornamenti.** Nelle build Windows, Linux e Android
  scaricate da GitHub, l'app chiede a `api.github.com` l'ultima versione.
  GitHub vede il tuo indirizzo IP, come per qualunque richiesta web. Le
  build degli store e di F-Droid non fanno questo controllo.

## Permessi

| Permesso | Perché |
|----------|--------|
| Internet, stato della rete | Collegarsi al sito WordPress |
| Fotocamera | Leggere barcode e QR; le immagini non vengono salvate né inviate |
| NFC | Leggere e scrivere le tessere di accesso dei dipendenti |
| Foto e file | Scegliere le immagini dei prodotti, importare ed esportare file |
| Rete locale (iOS) | Raggiungere un sito WordPress nella rete locale |

## I tuoi diritti

Lo sviluppatore non conserva dati personali tuoi o dei tuoi clienti. Per i
dati sul sito WordPress rivolgiti a chi lo gestisce. Per i dati inviati a
un provider IA vedi l'informativa privacy di quel provider.

## Contatti

Domande: [GitHub issues](https://github.com/Vincenzoferrara/mgws-inventory/issues).
