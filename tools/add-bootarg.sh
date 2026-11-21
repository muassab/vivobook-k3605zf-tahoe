#!/bin/sh
# Adiciona, substitui ou remove boot-args na EFI interna, com backup datado.
# Uso: sudo sh ~/mtk/add-bootarg.sh nvfbformat=0 nvfbrange=1
#      sudo sh ~/mtk/add-bootarg.sh --del nvfbformat nvfbrange
set -u
MODE=add
if [ "${1:-}" = "--del" ]; then MODE=del; shift; fi
[ $# -ge 1 ] || { echo "uso: $0 [--del] <arg|chave> [...]"; exit 1; }
DEV=disk0s1

diskutil mount "$DEV" >/dev/null 2>&1 || true
MP=$(diskutil info "$DEV" | sed -n 's/.*Mount Point: *//p' | head -1)
[ -n "$MP" ] || { echo "falha ao montar $DEV"; exit 1; }
OC="$MP/EFI/OC"

STAMP=$(date +%Y%m%d-%H%M%S)
BAK="$OC/config.plist.bak-bootargs-$STAMP"
cp "$OC/config.plist" "$BAK" || { echo "falha no backup"; exit 1; }
echo "backup: $BAK"

python3 - "$OC/config.plist" "$MODE" "$@" <<'PY'
import plistlib, sys
p, mode, want = sys.argv[1], sys.argv[2], sys.argv[3:]
GUID = "7C436110-AB2A-4BBB-A880-FE41995C9F82"

d = plistlib.load(open(p, "rb"))
g = d["NVRAM"]["Add"][GUID]
cur = g.get("boot-args", "").split()
keys = [a.split("=", 1)[0] for a in want]

if mode == "del":
    before = len(cur)
    cur = [x for x in cur if x.split("=", 1)[0] not in keys]
    print("removidos: %d" % (before - len(cur)))
else:
    for a in want:
        key = a.split("=", 1)[0]
        cur = [x for x in cur if x.split("=", 1)[0] != key]
        cur.append(a)
    print("aplicados:", " ".join(want))

g["boot-args"] = " ".join(cur)
dele = d["NVRAM"]["Delete"].setdefault(GUID, [])
if "boot-args" not in dele:
    dele.append("boot-args")

plistlib.dump(d, open(p, "wb"))
print("boot-args:", g["boot-args"])
PY

plutil -lint -s "$OC/config.plist" && echo PLIST_OK
echo "reiniciar para valer"
