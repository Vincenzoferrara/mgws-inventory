#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_DIR="$ROOT_DIR/android/keystore"
KEYSTORE_PATH="$KEY_DIR/gestione_negozio_abbigliamento-release.jks"
BASE64_PATH="$KEYSTORE_PATH.base64"
KEY_PROPERTIES_PATH="$ROOT_DIR/android/key.properties"
KEY_ALIAS="gestione_negozio_abbigliamento"

mkdir -p "$KEY_DIR"

if [[ -e "$KEYSTORE_PATH" ]]; then
  printf 'Keystore already exists: %s\n' "$KEYSTORE_PATH" >&2
  exit 1
fi

read -r -s -p "Android keystore password: " STORE_PASSWORD
printf '\n'
read -r -s -p "Android key password: " KEY_PASSWORD
printf '\n'

keytool -genkeypair \
  -v \
  -keystore "$KEYSTORE_PATH" \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "$KEY_ALIAS" \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -dname "CN=MGWS, OU=Gestione Negozio, O=MGWS, L=Italia, ST=Italia, C=IT"

cat > "$KEY_PROPERTIES_PATH" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=keystore/gestione_negozio_abbigliamento-release.jks
EOF

base64 -w 0 "$KEYSTORE_PATH" > "$BASE64_PATH"

printf '\nCreati file locali ignorati da Git:\n'
printf '- %s\n' "$KEYSTORE_PATH"
printf '- %s\n' "$KEY_PROPERTIES_PATH"
printf '- %s\n' "$BASE64_PATH"
printf '\nCarica i secret GitHub con:\n'
printf 'gh secret set ANDROID_KEYSTORE_BASE64 < "%s"\n' "$BASE64_PATH"
printf 'gh secret set ANDROID_KEY_ALIAS --body "%s"\n' "$KEY_ALIAS"
printf 'gh secret set ANDROID_KEY_PASSWORD --body "<password chiave>"\n'
printf 'gh secret set ANDROID_STORE_PASSWORD --body "<password keystore>"\n'
