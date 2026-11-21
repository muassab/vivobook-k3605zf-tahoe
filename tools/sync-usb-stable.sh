#!/bin/sh
# Espelha a EFI/OC interna (estado estavel: Wi-Fi + Bluetooth) para o pendrive.
# Faz backup datado da EFI/OC do pendrive antes de escrever.
# Rodar com sudo: sudo sh ~/mtk/sync-usb-stable.sh
set -u
DEV=disk0s1

USB=${1:-}
if [ -z "$USB" ]; then
	for v in /Volumes/*; do
		[ -f "$v/EFI/OC/config.plist" ] || continue
		vd=$(diskutil info "$v" 2>/dev/null | sed -n 's/.*Device Identifier: *//p' | head -1)
		[ "$vd" = "$DEV" ] && continue
		USB="$v"
		break
	done
fi
[ -n "$USB" ] || { echo "pendrive nao encontrado (monte e tente de novo)"; exit 1; }

[ -d "$USB/EFI/OC" ] || { echo "sem $USB/EFI/OC"; exit 1; }

diskutil mount "$DEV" >/dev/null 2>&1 || true
MP=$(diskutil info "$DEV" | sed -n 's/.*Mount Point: *//p' | head -1)
[ -n "$MP" ] || { echo "falha ao montar $DEV"; exit 1; }
INT="$MP/EFI"
DST="$USB/EFI"

echo "== espaco no pendrive =="
df -h "$USB" | tail -1

STAMP=$(date +%Y%m%d-%H%M%S)
BAK="$USB/EFI/OC.bak-$STAMP"
cp -R "$DST/OC" "$BAK" || { echo "falha no backup; abortando"; exit 1; }
echo "backup do pendrive: $BAK"

for d in Kexts ACPI Drivers Resources Tools; do
	[ -d "$INT/OC/$d" ] || continue
	mkdir -p "$DST/OC/$d"
	cp -R "$INT/OC/$d/." "$DST/OC/$d/" || { echo "falha copiando $d"; exit 1; }
done
cp "$INT/OC/OpenCore.efi" "$DST/OC/OpenCore.efi" || exit 1
cp "$INT/OC/config.plist" "$DST/OC/config.plist" || exit 1
mkdir -p "$DST/BOOT"
cp "$INT/BOOT/BOOTx64.efi" "$DST/BOOT/BOOTx64.efi" || exit 1
sync

echo
echo "== md5 =="
for f in OC/OpenCore.efi OC/config.plist BOOT/BOOTx64.efi; do
	echo "$f"
	echo "  int: $(md5 -q "$INT/$f")"
	echo "  usb: $(md5 -q "$DST/$f")"
done

echo
plutil -lint -s "$DST/OC/config.plist" && echo "PLIST_OK"

python3 - "$INT/OC" "$DST/OC" <<'PY'
import os, plistlib, subprocess, sys
int_oc, usb_oc = sys.argv[1], sys.argv[2]
d = plistlib.load(open(os.path.join(usb_oc, "config.plist"), "rb"))
print("\n== Kernel > Add (pendrive) ==")
bad = 0
for e in d["Kernel"]["Add"]:
    if not e.get("Enabled"):
        continue
    bp = e.get("BundlePath", "")
    ex = e.get("ExecutablePath")
    if ex:
        rel = ex if ex.startswith(bp) else os.path.join(bp, ex)
    else:
        rel = os.path.join(bp, e.get("PlistPath") or "Contents/Info.plist")
    a = os.path.join(int_oc, "Kexts", rel)
    b = os.path.join(usb_oc, "Kexts", rel)
    if not os.path.exists(b):
        print("  FALTA %-40s" % bp)
        bad += 1
        continue
    ma = subprocess.run(["md5", "-q", a], capture_output=True, text=True).stdout.strip()
    mb = subprocess.run(["md5", "-q", b], capture_output=True, text=True).stdout.strip()
    tag = "ok" if ma == mb else "DIFERENTE"
    if ma != mb:
        bad += 1
    print("  %-9s %s" % (tag, bp))
print("\n== ACPI (pendrive) ==")
for e in d["ACPI"]["Add"]:
    if e.get("Enabled"):
        p = os.path.join(usb_oc, "ACPI", e["Path"])
        print("  %-9s %s" % ("ok" if os.path.exists(p) else "FALTA", e["Path"]))
        if not os.path.exists(p):
            bad += 1
print("\nproblemas: %d" % bad)
PY

echo
echo "ejetar quando terminar: diskutil eject disk2"
