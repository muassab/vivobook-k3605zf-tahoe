#!/bin/sh
# Habilita a dGPU: remove disable-gpu do DeviceProperties e desabilita
# SSDT-dGPU-Off no ACPI. Faz backup datado da config antes.
# Rodar com sudo: sudo sh ~/mtk/enable-dgpu.sh
set -u
DEV=disk0s1

diskutil mount "$DEV" >/dev/null 2>&1 || true
MP=$(diskutil info "$DEV" | sed -n 's/.*Mount Point: *//p' | head -1)
[ -n "$MP" ] || { echo "falha ao montar $DEV"; exit 1; }
OC="$MP/EFI/OC"

STAMP=$(date +%Y%m%d-%H%M%S)
BAK="$OC/config.plist.bak-pre-dgpu-$STAMP"
cp "$OC/config.plist" "$BAK" || { echo "falha no backup"; exit 1; }
echo "backup: $BAK"

python3 - "$OC/config.plist" <<'PY'
import plistlib, sys
p = sys.argv[1]
d = plistlib.load(open(p, "rb"))
changed = []

dp = d["DeviceProperties"]["Add"]
key = "PciRoot(0x0)/Pci(0x1,0x0)/Pci(0x0,0x0)"
if key in dp:
    if "disable-gpu" in dp[key]:
        del dp[key]["disable-gpu"]
        changed.append("removeu disable-gpu de " + key)
    if not dp[key]:
        del dp[key]
        changed.append("removeu entrada DeviceProperties vazia")

for e in d["ACPI"]["Add"]:
    if e.get("Path") == "SSDT-dGPU-Off.aml" and e.get("Enabled"):
        e["Enabled"] = False
        changed.append("desabilitou SSDT-dGPU-Off.aml")

plistlib.dump(d, open(p, "wb"))
print("\n".join(changed) if changed else "nada a mudar")
PY

plutil -lint -s "$OC/config.plist" && echo PLIST_OK

python3 - "$OC/config.plist" <<'PY'
import plistlib, sys
d = plistlib.load(open(sys.argv[1], "rb"))
print("ACPI habilitado:", [e["Path"] for e in d["ACPI"]["Add"] if e.get("Enabled")])
print("DeviceProperties:", list(d["DeviceProperties"]["Add"].keys()))
PY

echo
echo "rollback: sudo sh ~/mtk/restore-efi-config.sh pre-dgpu"
