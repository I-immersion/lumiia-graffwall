#!/bin/bash
# LUMIIA — Mur de Graff : deploiement vers GitHub Pages.
# Usage : ./deploy.sh
#
# Le script vit dans le depot (Page des photos). Il va chercher les fichiers
# les plus recents dans le depot, dans le dossier parent (Game GraphWall) et
# dans Telechargements — peu importe qu'ils s'appellent mur.html ou
# graffwall_v3.3.html. Il verifie ensuite que le jeu et la galerie portent le
# meme numero de version avant de commiter et pousser.

set -u
DEPOT="$(cd "$(dirname "$0")" && pwd)"
cd "$DEPOT" || exit 1
shopt -s nullglob

vert()  { printf '\033[32m%s\033[0m\n' "$1"; }
rouge() { printf '\033[31m%s\033[0m\n' "$1"; }
gris()  { printf '\033[90m%s\033[0m\n' "$1"; }

PARENT="$(dirname "$DEPOT")"
ARCHIVES="$PARENT/Versions"
# Telechargements en premier : c'est la que les fichiers arrivent
SOURCES=("$HOME/Downloads" "$HOME/Desktop" "$DEPOT" "$PARENT")
VENUS=()

# --- cherche le fichier le plus recent correspondant aux motifs donnes ---
trouver() {
  local cands=() d f
  for d in "${SOURCES[@]}"; do
    [ -d "$d" ] || continue
    for f in "$d"/$1 "$d"/$2; do
      [ -f "$f" ] && cands+=("$f")
    done
  done
  [ ${#cands[@]} -eq 0 ] && return 1
  ls -t "${cands[@]}" 2>/dev/null | head -1
}

recuperer() {   # $1 = nom cible, $2 = motif exact, $3 = motif versionne
  local src
  src="$(trouver "$2" "$3")" || { rouge "INTROUVABLE : $1"; return 1; }
  if [ "$src" != "$DEPOT/$1" ]; then
    cp -f "$src" "$DEPOT/$1" || return 1
    gris "  $1  <-  $src"
    VENUS+=("$src")
  else
    gris "  $1  (deja dans le depot)"
  fi
  return 0
}

echo "Fichiers retenus :"
recuperer "mur.html"   "mur.html"   "graffwall_v*.html"         || MANQUE=1
recuperer "index.html" "index.html" "graffwall_galerie_v*.html" || MANQUE=1
recuperer "photo.html" "photo.html" "graffwall_photo_v*.html"   || MANQUE=1
if [ "${MANQUE:-0}" = "1" ]; then
  echo
  echo "Dossiers explores :"
  for d in "${SOURCES[@]}"; do echo "  $d"; done
  exit 1
fi

# --- on ne garde pas de doublons versionnes dans le depot ---
rm -f "$DEPOT"/graffwall_*.html "$DEPOT"/.DS_Store

# --- les deux versions doivent concorder ---
VJEU=$(grep -o 'var VERSION = "v[0-9][0-9.]*"' mur.html | grep -o 'v[0-9][0-9.]*' | head -1)
VGAL=$(grep -o 'GALERIE v[0-9][0-9.]*' index.html | grep -o 'v[0-9][0-9.]*' | head -1)
VPHO=$(grep -o 'PHOTO v[0-9][0-9.]*' photo.html | grep -o 'v[0-9][0-9.]*' | head -1)

if [ -z "$VJEU" ] || [ -z "$VGAL" ] || [ -z "$VPHO" ]; then
  rouge "Version illisible (jeu='$VJEU' galerie='$VGAL' photo='$VPHO')"; exit 1
fi
if [ "$VJEU" != "$VGAL" ] || [ "$VJEU" != "$VPHO" ]; then
  rouge "VERSIONS DIFFERENTES — jeu $VJEU, galerie $VGAL, photo $VPHO"
  echo "Le projet exporte toujours les trois ensemble. Rien n'a ete pousse."
  exit 1
fi
vert "version $VJEU (jeu, galerie et page photo)"

# --- y a-t-il quelque chose a envoyer ---
if [ -z "$(git status --porcelain)" ]; then
  echo "Rien de nouveau, le depot est deja a jour."
  exit 0
fi
git status --short

git add -A || exit 1
git commit -m "$VJEU jeu + galerie + photo" || exit 1
if git push; then
  vert "En ligne : https://i-immersion.github.io/lumiia-graffwall/"
  echo "(GitHub Pages met une a deux minutes a se rafraichir)"

  # --- rangement : les fichiers versionnes rejoignent les archives ---
  mkdir -p "$ARCHIVES"
  RANGES=0
  for f in "${VENUS[@]:-}"; do
    [ -z "$f" ] && continue
    case "$(basename "$f")" in
      graffwall_*_v*.html|graffwall_v*.html)
        if [ "$(dirname "$f")" != "$ARCHIVES" ]; then
          mv -f "$f" "$ARCHIVES/" 2>/dev/null && RANGES=$((RANGES+1))
        fi ;;
    esac
  done
  [ "$RANGES" -gt 0 ] && gris "  $RANGES fichier(s) range(s) dans $ARCHIVES"
else
  rouge "Push refuse. Si le depot distant a de l'avance :"
  echo "  git pull --rebase origin main && git push"
  exit 1
fi

echo ""
echo "— fenetre laissee ouverte, tu peux la fermer —"
