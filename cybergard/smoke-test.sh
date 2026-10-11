#!/usr/bin/env bash
# ============================================================================
# smoke-test.sh <image> — démarrage de test isolé de l'image Keila.
#
# Lance postgres:15.12-alpine + l'image sur un réseau Docker éphémère, avec des
# secrets JETABLES générés pour le test (jamais réutilisés), puis vérifie :
#   1. connexion PostgreSQL + migrations appliquées
#   2. healthcheck du compose prod (wget /auth/login) DANS le conteneur
#   3. /auth/login répond 200 et porte le branding « Cybergard AI »
#   4. compte admin créé depuis KEILA_USER (seeds, base vide)
#   5. lien « Source code » (AGPL §13) vers SOURCE_URL exacte (VERSION.env)
# Aucun e-mail envoyé (SMTP pointé vers un hôte inexistant, non sollicité).
# Nettoyage systématique (conteneurs, réseau, volume) en sortie.
# ============================================================================
set -Eeuo pipefail
KEILA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
image="${1:?usage : smoke-test.sh <image>}"
if [[ -z "${SOURCE_URL:-}" ]]; then
  # shellcheck source=VERSION.env
  source "$KEILA_DIR/VERSION.env"
fi
id="keila-smoke-$$"
net="$id-net"
pg_image="postgres:15.12-alpine"
admin_email="smoke-admin@example.invalid"

cleanup() {
  docker rm -f "$id-app" "$id-db" >/dev/null 2>&1 || true
  docker network rm "$net" >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() { echo "FAIL $*" >&2; docker logs --tail 40 "$id-app" 2>&1 | grep -viE 'password|secret' >&2 || true; exit 1; }
ok()   { echo "OK   $*" >&2; }

db_pw="$(openssl rand -hex 16 | tr -d '\r\n')"
skb="$(openssl rand -base64 64 | tr -d '\r\n')"
salt="$(openssl rand -hex 24 | tr -d '\r\n')"
admin_pw="$(openssl rand -base64 18 | tr -d '\r\n')"

docker network create "$net" >/dev/null
docker run -d --name "$id-db" --network "$net" --network-alias keila-db \
  -e POSTGRES_DB=keila -e POSTGRES_USER=keila -e POSTGRES_PASSWORD="$db_pw" "$pg_image" >/dev/null

for _ in $(seq 1 30); do
  docker exec "$id-db" pg_isready -U keila -d keila >/dev/null 2>&1 && break
  sleep 2
done
docker exec "$id-db" pg_isready -U keila -d keila >/dev/null 2>&1 || fail "1.PostgreSQL ne démarre pas"
ok "1.PostgreSQL prêt"

docker run -d --name "$id-app" --network "$net" \
  -e DB_URL="ecto://keila:$db_pw@keila-db/keila" \
  -e SECRET_KEY_BASE="$skb" -e HASHID_SALT="$salt" \
  -e URL_HOST=localhost -e URL_SCHEMA=http -e URL_PORT=4000 \
  -e MAILER_SMTP_HOST=smtp.invalid -e MAILER_SMTP_PORT=587 \
  -e MAILER_SMTP_USER=smoke -e MAILER_SMTP_PASSWORD=smoke \
  -e MAILER_SMTP_FROM_EMAIL=smoke@example.invalid -e MAILER_SMTP_TLS_MODE=starttls \
  -e KEILA_USER="$admin_email" -e KEILA_PASSWORD="$admin_pw" \
  -e DISABLE_REGISTRATION=true -e DISABLE_UPDATE_CHECKS=true \
  "$image" >/dev/null

# Même commande que le healthcheck de docker-compose.prod.yml
healthy=0
for _ in $(seq 1 60); do
  [[ "$(docker inspect -f '{{.State.Running}}' "$id-app" 2>/dev/null)" == "true" ]] || fail "2.le conteneur Keila s'est arrêté"
  if docker exec "$id-app" sh -c 'wget -q -O /dev/null http://127.0.0.1:4000/auth/login'; then healthy=1; break; fi
  sleep 3
done
(( healthy )) || fail "2.healthcheck wget /auth/login KO après 180 s"
ok "2.healthcheck (wget /auth/login) OK dans le conteneur"

page="$(docker exec "$id-app" sh -c 'wget -q -O - http://127.0.0.1:4000/auth/login')"
grep -q "Cybergard AI" <<<"$page" || fail "3.branding « Cybergard AI » absent de /auth/login"
if grep -Eq '· Keila[[:space:]]*($|<)' <<<"$page"; then fail "3.titre « · Keila » encore présent"; fi
ok "3./auth/login brandé « Cybergard AI »"

source_line="$(grep -F 'data-cybergard-source' <<<"$page" || true)"
grep -qF "href=\"$SOURCE_URL\"" <<<"$source_line" || fail "5.lien « Source code » vers $SOURCE_URL absent de /auth/login"
grep -qF "Source code" <<<"$page" || fail "5.libellé « Source code » absent"
ok "5.lien « Source code » présent : $SOURCE_URL"

migrations="$(docker exec "$id-db" psql -U keila -d keila -tAc 'SELECT count(*) FROM schema_migrations')"
users="$(docker exec "$id-db" psql -U keila -d keila -tAc "SELECT count(*) FROM users WHERE email = '$admin_email'")"
[[ "${migrations:-0}" -gt 0 ]] || fail "1.aucune migration appliquée"
[[ "$users" == "1" ]] || fail "4.compte admin non créé (users=$users)"
ok "1.migrations appliquées ($migrations) ; 4.compte admin créé depuis KEILA_USER"

if docker logs "$id-app" 2>&1 | grep -q "KEILA_PASSWORD not set"; then fail "4.KEILA_PASSWORD ignoré"; fi
echo "Smoke test Keila OK : $image" >&2
