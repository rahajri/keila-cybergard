#!/usr/bin/env bash
# ============================================================================
# cybergard/verify-against-upstream.sh — prouve que ce dépôt = Keila officiel
# v0.30.3 (commit épinglé) + uniquement les modifications Cybergard décrites.
#
#   1. récupère pentacent/keila au tag/commit de VERSION.env (fetch-source.sh)
#   2. y applique apply-branding.sh
#   3. compare l'arbre obtenu avec ce dépôt (hors .git, cybergard/ et README.md)
#
# Sortie 0 = identique octet pour octet.
# ============================================================================
set -Eeuo pipefail
CYB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CYB_DIR/.." && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

bash "$CYB_DIR/fetch-source.sh" "$work/upstream"
bash "$CYB_DIR/apply-branding.sh" "$work/upstream"

if diff -r -q \
     --exclude=.git --exclude=cybergard --exclude=README.md \
     "$work/upstream" "$ROOT"; then
  echo "OK : ce dépôt est identique à pentacent/keila v0.30.3 + branding Cybergard" >&2
else
  echo "ÉCART : ce dépôt diffère de upstream + apply-branding.sh (voir ci-dessus)" >&2
  exit 1
fi
