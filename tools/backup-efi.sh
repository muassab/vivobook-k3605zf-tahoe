#!/bin/sh
# Copia a EFI/OC interna para ~/mtk/efi-backup-<tag>/ com manifesto md5.
# Rodar com sudo: sudo sh ~/mtk/backup-efi.sh <tag>
set -u
[ $# -ge 1 ] || { echo "uso: $0 <tag>"; exit 1; }
DEV=disk0s1
TAG="$1"
DIR=$(cd "$(dirname "$0")" && pwd)
OUT="$DIR/efi-backup-$TAG"

diskutil mount "$DEV" >/dev/null 2>&1 || true
MP=$(diskutil info "$DEV" | sed -n 's/.*Mount Point: *//p' | head -1)
[ -n "$MP" ] || { echo "falha ao montar $DEV"; exit 1; }
[ -d "$MP/EFI/OC" ] || { echo "sem $MP/EFI/OC"; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$MP/EFI/OC/." "$OUT/" || { echo "falha ao copiar"; exit 1; }
( cd "$OUT" && find . -type f -exec md5 -q {} \; -print | paste - - > manifest-md5.txt )

chown -R "$(stat -f%Su /dev/console)" "$OUT" 2>/dev/null

echo "backup: $OUT"
du -sh "$OUT"
echo
echo "config md5: $(md5 -q "$OUT/config.plist")"
echo "arquivos:   $(find "$OUT" -type f | wc -l | tr -d ' ')"
