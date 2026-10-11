#!/usr/bin/env bash
# ============================================================================
# fetch-source.sh <dest> — récupère le source officiel Keila à la version
# épinglée dans VERSION.env et vérifie le commit exact (supply chain).
# ============================================================================
set -Eeuo pipefail
KEILA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=VERSION.env
source "$KEILA_DIR/VERSION.env"

dest="${1:?usage : fetch-source.sh <dossier de destination>}"
[[ ! -e "$dest" ]] || { echo "ERREUR: $dest existe déjà" >&2; exit 1; }

# core.autocrlf=false : source identique octet pour octet quel que soit l'OS
# (sous Windows, la conversion CRLF casse la compilation des templates CSS de Keila).
git -c advice.detachedHead=false -c core.autocrlf=false -c core.eol=lf \
  clone --quiet --depth 1 --branch "$KEILA_GIT_REF" "$KEILA_REPO" "$dest"
if grep -rIlq $'\r' "$dest/lib" "$dest/priv" 2>/dev/null; then
  echo "ERREUR: fins de ligne CRLF détectées dans le source Keila (conversion Git ?)" >&2
  exit 1
fi
actual="$(git -C "$dest" rev-parse HEAD)"
if [[ "$actual" != "$KEILA_COMMIT" ]]; then
  echo "ERREUR: $KEILA_GIT_REF pointe sur $actual, attendu $KEILA_COMMIT (tag déplacé ?)" >&2
  exit 1
fi
echo "Source Keila $KEILA_VERSION récupéré ($KEILA_GIT_REF @ $actual)" >&2
