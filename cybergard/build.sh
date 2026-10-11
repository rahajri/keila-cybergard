#!/usr/bin/env bash
# ============================================================================
# cybergard/build.sh — construit l'image Keila Cybergard depuis CE dépôt.
#
# Ce dépôt contient déjà le source Keila v0.30.3 modifié (branding Cybergard +
# lien « Source code »). Il suffit donc de lancer, depuis n'importe où :
#
#   bash cybergard/build.sh            # → keila-cybergard:0.30.3-cybergard.1
#
# Même Dockerfile et même image de base épinglée que l'image déployée
# (ghcr.io/rahajri/keila:0.30.3-cybergard.1).
# ============================================================================
set -Eeuo pipefail
CYB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CYB_DIR/.." && pwd)"
# shellcheck source=VERSION.env
source "$CYB_DIR/VERSION.env"

tag="${IMAGE_TAG:-keila-cybergard:${KEILA_VERSION}-cybergard.${CYBERGARD_REVISION}}"

docker build \
  --build-arg "ELIXIR_IMAGE=$ELIXIR_IMAGE" \
  --build-arg "KEILA_VERSION=$KEILA_VERSION" \
  --build-arg "KEILA_COMMIT=$KEILA_COMMIT" \
  --build-arg "CYBERGARD_REVISION=$CYBERGARD_REVISION" \
  -f "$CYB_DIR/Dockerfile" -t "$tag" "$ROOT"

echo "Image construite : $tag" >&2
echo "Test : bash cybergard/smoke-test.sh $tag" >&2
