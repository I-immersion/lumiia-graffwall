#!/bin/bash
# LUMIIA — Mur de Graff : deploiement vers GitHub Pages.
# Usage : ./deploy.sh
#
# Version : v1.1 — depuis la v1.1, recopie aussi mur.html dans la Defoule Room.
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

# --- une livraison groupee arrive en un seul zip : on le deballe d'abord ---
for z in "$HOME/Downloads"/graffwall*.zip "$HOME/Desktop"/graffwall*.zip; do
  [ -f "$z" ] || continue
  if unzip -o -j -q "$z" -d "$HOME/Downloads" 'graffwall*.html' 2>/dev/null; then
    gris "  archive deballee : $(basename "$z")"
    rm -f "$z"
  else
    rouge "  archive illisible : $(basename "$z")"
  fi
done

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

# --- le mur part aussi dans la Defoule Room -------------------------
# Le mur existe en deux exemplaires : celui du depot, publie en ligne, et
# une copie locale que la Defoule Room ouvre dans sa tuile GRAFF (elle
# tourne hors ligne en soiree, elle ne peut donc pas viser l'adresse
# publique). Deux copies synchronisees a la main finissent toujours par
# diverger : c'est arrive. On recopie donc ici, a chaque deploiement.
# Cible : chaque sous-dossier de "Game-shooter + graff Wall" qui contient
# le jeu. Un dossier renomme suit tout seul ; les archives, qui rangent le
# jeu un cran plus bas, ne sont pas touchees.
JEUX="$(dirname "$PARENT")/Game-shooter + graff Wall"
PORTES=0
if [ -d "$JEUX" ]; then
  for d in "$JEUX"/*/; do
    [ -f "$d/lumiia-defoule-room.html" ] || continue
    if cp -f "$DEPOT/mur.html" "$d/mur.html"; then
      gris "  mur.html  ->  $(basename "$d")"
      PORTES=$((PORTES+1))
    fi
  done
fi
if [ "$PORTES" -eq 0 ]; then
  rouge "Defoule Room introuvable : le mur n'a ete recopie nulle part."
  echo "  cherche dans : $JEUX"
else
  vert "mur.html recopie dans $PORTES dossier(s) Defoule Room"
fi


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