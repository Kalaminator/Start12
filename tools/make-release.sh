#!/bin/sh
# Build dist/org.win12.menu-<version>.plasmoid (zip of package/) for the KDE Store.
# Version = package/metadata.json KPlugin.Version (bump it by hand first). Only git-tracked files go in,
# so the Stardock assets listed in .gitignore are never shipped.
set -e
cd "$(dirname "$0")/.."
VER=$(python3 -c 'import json; print(json.load(open("package/metadata.json"))["KPlugin"]["Version"])')
OUT="$PWD/dist/org.win12.menu-$VER.plasmoid"
mkdir -p dist
rm -f "$OUT"
cd package
git ls-files -z . | xargs -0 zip -q -X "$OUT"
cd ..
if unzip -Z1 "$OUT" | grep -E 'StartButtons/|MenuTextures/|TabTextures/|StartIcon\.svg'; then
    echo "Stardock assets inside the zip" >&2; rm -f "$OUT"; exit 1
fi
echo "$OUT"
