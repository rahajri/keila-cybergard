#!/usr/bin/env bash
# ============================================================================
# apply-branding.sh <source_keila> — applique le branding Cybergard AI.
#
# Reprend les 3 personnalisations historiques (image ghcr.io/cybergard/keila:custom) :
#   1. layout principal       lib/keila_web/templates/layout/root.html.heex
#        <title> … · Keila  → … · Cybergard AI
#   2. layout formulaire      lib/keila_web/templates/public_form_layout/root.html.heex
#        <title> … · Keila  → … · Cybergard AI
#   3. menu                   lib/keila_web/templates/layout/_menu.html.heex
#        libellé « Keila » à côté du logo (menu latéral + menu mobile) → Cybergard AI
#
# Et ajoute le lien « Source code » exigé par l'AGPL-3.0 §13, vers le tag exact
# du dépôt public correspondant (SOURCE_URL, VERSION.env) :
#   4. pied de page du layout principal (page de connexion + interface)
#        lib/keila_web/templates/layout/_footer.html.heex, colonne « Community »
#   5. pied de page des formulaires publics (abonnement)
#        lib/keila_web/templates/public_form_layout/root.html.heex, sous <main>
#
# Remplacements/insertions EXACTS avec nombre d'occurrences attendu : si
# l'upstream change ces templates, le script échoue au lieu de produire une
# image mal brandée. Aucune autre modification (logique, routes, logo SVG).
# ============================================================================
set -Eeuo pipefail
KEILA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

src="${1:?usage : apply-branding.sh <dossier source Keila>}"
BRAND="${CYBERGARD_BRAND:-Cybergard AI}"
if [[ -z "${SOURCE_URL:-}" ]]; then
  # shellcheck source=VERSION.env
  source "$KEILA_DIR/VERSION.env"
fi
[[ "$SOURCE_URL" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/tree/v[0-9][A-Za-z0-9_.-]*$ ]] \
  || { echo "ERREUR: SOURCE_URL invalide : '$SOURCE_URL'" >&2; exit 1; }

check_count() {
  local file="$1" needle="$2" expected="$3" count
  count="$(grep -cF -- "$needle" "$file" || true)"
  if [[ "$count" != "$expected" ]]; then
    echo "ERREUR: ${file#"$src"/} : $count occurrence(s) de « ${needle%%$'\n'*} », $expected attendue(s) — template upstream modifié ?" >&2
    exit 1
  fi
}

replace_exact() {
  local file="$src/$1" from="$2" to="$3" expected="$4"
  [[ -f "$file" ]] || { echo "ERREUR: $1 introuvable" >&2; exit 1; }
  check_count "$file" "$from" "$expected"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$file"
  [[ "$(grep -cF -- "$to" "$file")" -ge "$expected" ]] || { echo "ERREUR: remplacement non appliqué dans $1" >&2; exit 1; }
  echo "OK  $1 : $expected × « $from » → « $to »" >&2
}

# Insère un bloc (multi-lignes) juste après une ancre multi-lignes unique.
insert_after_exact() {
  local file="$src/$1" anchor="$2" block="$3" marker="$4"
  [[ -f "$file" ]] || { echo "ERREUR: $1 introuvable" >&2; exit 1; }
  if [[ "$(ANCHOR="$anchor" perl -0ne 'print scalar(() = /\Q$ENV{ANCHOR}\E/g)' "$file")" != "1" ]]; then
    echo "ERREUR: $1 : ancre d'insertion absente ou non unique — template upstream modifié ?" >&2
    exit 1
  fi
  ANCHOR="$anchor" BLOCK="$block" perl -0pi -e 's/\Q$ENV{ANCHOR}\E/$ENV{ANCHOR}$ENV{BLOCK}/' "$file"
  check_count "$file" "$marker" 1
  echo "OK  $1 : lien « Source code » → $SOURCE_URL" >&2
}

# --- 1 à 3 : branding historique ---------------------------------------------
replace_exact "lib/keila_web/templates/layout/root.html.heex" \
  ') <> " · Keila"}' ") <> \" · $BRAND\"}" 1
replace_exact "lib/keila_web/templates/public_form_layout/root.html.heex" \
  ') <> " · Keila"}' ") <> \" · $BRAND\"}" 1
replace_exact "lib/keila_web/templates/layout/_menu.html.heex" \
  '<span class="text-2xl font-light">Keila</span>' "<span class=\"text-2xl font-light\">$BRAND</span>" 1
replace_exact "lib/keila_web/templates/layout/_menu.html.heex" \
  '<span class="text-3xl font-light">Keila</span>' "<span class=\"text-3xl font-light\">$BRAND</span>" 1

# --- 4 : lien « Source code » dans le pied de page principal -----------------
footer_anchor='            <a class="block hover:underline" href="https://www.github.com/pentacent/keila">
              GitHub
            </a>
          </li>
'
footer_block="          <li>
            <a class=\"block hover:underline\" href=\"$SOURCE_URL\" rel=\"noopener\" data-cybergard-source>
              Source code
            </a>
          </li>
"
insert_after_exact "lib/keila_web/templates/layout/_footer.html.heex" \
  "$footer_anchor" "$footer_block" "data-cybergard-source"

# --- 5 : lien « Source code » sous les formulaires publics -------------------
form_anchor='    <main>
      {@inner_content}
    </main>
'
form_block="    <footer class=\"mt-auto pt-6 text-center text-xs\">
      <a class=\"underline\" href=\"$SOURCE_URL\" rel=\"noopener\" data-cybergard-source>Source code</a>
    </footer>
"
insert_after_exact "lib/keila_web/templates/public_form_layout/root.html.heex" \
  "$form_anchor" "$form_block" "data-cybergard-source"

echo "Branding « $BRAND » + lien source appliqués" >&2
