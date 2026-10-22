# Security

[Documentation index](README.md)

To report a vulnerability, see [SECURITY.md](../../SECURITY.md). What the
app stores and sends is described in the [privacy policy](../../PRIVACY.md).

## Principles

- Login is the most sensitive part of the app. Every change to it is
  reviewed for security before it is written; login methods are secure by
  default and have no insecure fallback or temporary shortcut.
- Secrets are never stored or sent in clear text.
- The endpoint is verified before credentials are saved, and JWT
  credentials are never sent to a site without a JWT route.
- Public errors never expose SQL, tokens, passwords, local paths or other
  customers' data.
- The app never bypasses MGWS permission checks: the plugin decides who can
  do what.

## Credentials on the device

- WordPress passwords, Application Passwords, JWT tokens, WooCommerce keys,
  AI keys and CalDAV credentials are kept in the secure storage of the
  operating system (`flutter_secure_storage`).
- Logging out deletes them (`SecureStorageService.clearAll()`).
- Preferences synced with the site never include secrets.
- The logged-in username is stored as an identifier only, to attribute POS
  receipts to the operator, and is deleted at logout.

## Local development

The local development option allows `localhost` and private LAN addresses,
including WordPress Admin login over plain HTTP. Use it only with trusted
local sites. Change test credentials before going live, and keep
configuration files out of public backups and repositories.

## Logs

- Logs stay in memory; files are written only when the user records a
  temporary log, in the app's temporary folder, never in Documents or
  Downloads.
- Message, error and stack trace are sanitised at every level: passwords,
  tokens, JWTs, Bearer tokens, API keys, Application Passwords, secrets and
  consumer keys never appear in shared logs.
- Sharing the log and `Delete log` empty the memory buffer and the
  temporary files.

## Employee credentials

The app lists and revokes employee Application Passwords and WooCommerce
keys, but never creates them. Revocation needs `mgws_manage_credentials`,
which MGWS gives only to administrators. Disabling an employee does not
revoke their credentials: revoke them when someone leaves.

## Layout is not security

Showing the login as a full page on phones or as a dialog on large screens
is only a visual choice: it changes nothing in credential storage, tokens,
connectors or authentication rules.

## Privacy rules for new code

- No Google service as a required dependency; a feature that can work
  without Google must.
- No hidden tracking, telemetry, ads or unnecessary data collection.
- Prefer local, self-hosted, WordPress/MGWS and open-standard solutions.
- An optional external service (AI, Google…) is declared, stays optional
  and asks for consent before sending data; send the minimum needed.
