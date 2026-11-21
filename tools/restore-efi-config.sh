#!/bin/sh
# Restaura a config.plist da EFI interna a partir de um backup.
# Uso: sudo sh ~/mtk/restore-efi-config.sh <tag>
#   - se existir ~/mtk/efi-backup-<tag>/config.plist, usa ele
#   - senao usa o config.plist.bak-<tag>-* mais recente na EFI
# Rodar com sudo.
set -u
[ $# -ge 1 ] || { echo "uso: $0 <tag>   (ex.: pre-dgpu)"; exit 1; }
DEV=disk0s1
TAG="$1"
DIR=$(cd "$(dirname "$0")" && pwd)

diskutil mount "$DEV" >/dev/null 2>&1 || true
MP=$(diskutil info "$DEV" | sed -n 's/.*Mount Point: *//p' | head -1)
[ -n "$MP" ] || { echo "falha ao montar $DEV"; exit 1; }
OC="$MP/EFI/OC"

SRC=""
if [ -f "$DIR/efi-backup-$TAG/config.plist" ]; then
	SRC="$DIR/efi-backup-$TAG/config.plist"
else
	SRC=$(ls -1t "$OC"/config.plist.bak-"$TAG"-* 2>/dev/null | head -1)
fi
[ -n "$SRC" ] || { echo "sem backup para a tag '$TAG'"; exit 1; }

STAMP=$(date +%Y%m%d-%H%M%S)
cp "$OC/config.plist" "$OC/config.plist.bak-restore-$STAMP" 2>/dev/null
cp "$SRC" "$OC/config.plist" || { echo "falha ao restaurar"; exit 1; }
sync

plutil -lint -s "$OC/config.plist" && echo PLIST_OK
echo "restaurado de: $SRC"
python3 - "$OC/config.plist" <<'PY'
import plistlib, sys
d = plistlib.load(open(sys.argv[1], "rb"))
g = d["NVRAM"]["Add"]["7C436110-AB2A-4BBB-A880-FE41995C9F82"]
print("boot-args:", g.get("boot-args"))
print("csr:", g.get("csr-active-config").hex())
print("ACPI:", [e["Path"] for e in d["ACPI"]["Add"] if e.get("Enabled")])
print("DeviceProperties:", list(d["DeviceProperties"]["Add"].keys()))
PY
