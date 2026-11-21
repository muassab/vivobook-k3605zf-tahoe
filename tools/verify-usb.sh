#!/bin/sh
# Verifica se a EFI do pendrive bate com a EFI interna (sem copiar nada).
# Gera ~/mtk/verify-usb.txt.
# Rodar com sudo: sudo sh ~/mtk/verify-usb.sh
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
[ -n "$USB" ] || { echo "pendrive nao encontrado"; exit 1; }
DIR=$(cd "$(dirname "$0")" && pwd)
OUT="$DIR/verify-usb.txt"

{
	echo "date: $(date)"
	[ -d "$USB/EFI/OC" ] || { echo "pendrive nao montado em $USB/EFI/OC"; exit 1; }
	diskutil mount "$DEV" >/dev/null 2>&1 || true
	MP=$(diskutil info "$DEV" | sed -n 's/.*Mount Point: *//p' | head -1)
	echo "MP=[$MP]"
	[ -n "$MP" ] || { echo "FALHA ao montar $DEV"; exit 1; }
	INT="$MP/EFI"
	DST="$USB/EFI"
	echo "INT=$INT"
	echo "DST=$DST"
	echo "md5 bin: $(command -v md5)"

	echo
	echo "== arquivos base =="
	for f in OC/OpenCore.efi OC/config.plist BOOT/BOOTx64.efi; do
		echo "$f"
		echo "  int: $(md5 -q "$INT/$f" 2>&1)"
		echo "  usb: $(md5 -q "$DST/$f" 2>&1)"
	done

	echo
	python3 - "$INT/OC" "$DST/OC" <<'PY'
import os, plistlib, subprocess, sys
int_oc, usb_oc = sys.argv[1], sys.argv[2]

def md5(p):
    if not os.path.exists(p):
        return "AUSENTE"
    return subprocess.run(["md5", "-q", p], capture_output=True, text=True).stdout.strip() or "ERRO"

d = plistlib.load(open(os.path.join(usb_oc, "config.plist"), "rb"))
print("== Kernel > Add habilitados ==")
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
    ma = md5(os.path.join(int_oc, "Kexts", rel))
    mb = md5(os.path.join(usb_oc, "Kexts", rel))
    tag = "ok" if ma == mb and ma != "AUSENTE" else "PROBLEMA"
    if tag != "ok":
        bad += 1
        print("  %-9s %-40s int=%s usb=%s" % (tag, bp, ma[:8], mb[:8]))
    else:
        print("  %-9s %s" % (tag, bp))

print()
print("== ACPI habilitado ==")
for e in d["ACPI"]["Add"]:
    if not e.get("Enabled"):
        continue
    p = e["Path"]
    ma = md5(os.path.join(int_oc, "ACPI", p))
    mb = md5(os.path.join(usb_oc, "ACPI", p))
    tag = "ok" if ma == mb and ma != "AUSENTE" else "PROBLEMA"
    if tag != "ok":
        bad += 1
    print("  %-9s %-24s int=%s usb=%s" % (tag, p, ma[:8], mb[:8]))

print()
print("== Drivers ==")
for e in d["UEFI"]["Drivers"]:
    p = e["Path"] if isinstance(e, dict) else e
    if isinstance(e, dict) and not e.get("Enabled", True):
        continue
    ma = md5(os.path.join(int_oc, "Drivers", p))
    mb = md5(os.path.join(usb_oc, "Drivers", p))
    tag = "ok" if ma == mb and ma != "AUSENTE" else "PROBLEMA"
    if tag != "ok":
        bad += 1
    print("  %-9s %-24s int=%s usb=%s" % (tag, p, ma[:8], mb[:8]))

print()
print("problemas: %d" % bad)
PY
} > "$OUT" 2>&1

chown "${SUDO_USER:-$(stat -f%Su /dev/console)}" "$OUT" 2>/dev/null
cat "$OUT"
