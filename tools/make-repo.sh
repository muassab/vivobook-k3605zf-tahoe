#!/bin/sh
# Monta um pacote pronto para GitHub/Drive com a EFI interna sanitizada.
# Uso: sudo sh ~/mtk/make-repo.sh [nome]
# Saida: ~/mtk/repo-<nome>/ e ~/mtk/<nome>.zip
set -u
NAME=${1:-vivobook-k3605zf-tahoe}
DEV=disk0s1
DIR=$(cd "$(dirname "$0")" && pwd)
OUT="$DIR/repo-$NAME"
ZIP="$DIR/$NAME.zip"

diskutil mount "$DEV" >/dev/null 2>&1 || true
MP=$(diskutil info "$DEV" | sed -n 's/.*Mount Point: *//p' | head -1)
[ -n "$MP" ] || { echo "falha ao montar $DEV"; exit 1; }
OC="$MP/EFI/OC"
[ -f "$OC/config.plist" ] || { echo "sem $OC/config.plist"; exit 1; }

rm -rf "$OUT" "$ZIP"
mkdir -p "$OUT/EFI/OC" "$OUT/tools" "$OUT/docs"

cp -R "$OC/ACPI" "$OC/Kexts" "$OC/Drivers" "$OUT/EFI/OC/" || exit 1
cp "$OC/config.plist" "$OUT/EFI/OC/config.plist" || exit 1
[ -f "$OC/OpenCore.efi" ] && cp "$OC/OpenCore.efi" "$OUT/EFI/OC/"

for f in "$DIR"/add-bootarg.sh "$DIR"/backup-efi.sh "$DIR"/enable-dgpu.sh \
	"$DIR"/restore-efi-config.sh "$DIR"/verify-usb.sh "$DIR"/sync-usb-stable.sh \
	"$DIR"/make-repo.sh "$DIR"/gpu-policy.sh; do
	[ -f "$f" ] && cp "$f" "$OUT/tools/"
done

[ -f "$DIR/repo-README.md" ] && cp "$DIR/repo-README.md" "$OUT/README.md"
[ -f "$DIR/repo-README.pt-BR.md" ] && cp "$DIR/repo-README.pt-BR.md" "$OUT/README.pt-BR.md"
for f in PLANO-SLEEP.md PLANO-DGPU.md; do
	[ -f "$DIR/repo-docs/$f" ] && cp "$DIR/repo-docs/$f" "$OUT/docs/"
done

python3 - "$OUT/EFI/OC/config.plist" <<'PY'
import plistlib, sys
p = sys.argv[1]
d = plistlib.load(open(p, "rb"))
g = d["PlatformInfo"]["Generic"]
for k in ("SystemSerialNumber", "MLB", "SystemUUID", "ROM"):
    if k in g:
        if k == "ROM":
            g.pop(k)
        else:
            g[k] = "PUT-YOUR-OWN"
n = d["NVRAM"]["Add"]["7C436110-AB2A-4BBB-A880-FE41995C9F82"]
for k in ("bluetoothInternalControllerInfo", "bluetoothExternalDongleFailed"):
    n.pop(k, None)
plistlib.dump(d, open(p, "wb"), fmt=plistlib.FMT_XML)
print("config sanitizada: serial/MLB/UUID/ROM e dados de pareamento removidos")
PY

for kp in "$OUT"/EFI/OC/Kexts/*/Contents/Info.plist; do
	[ -f "$kp" ] || continue
	python3 - "$kp" <<'PY'
import plistlib, sys
p = sys.argv[1]
d = plistlib.load(open(p, "rb"))
hit = []

def walk(o, path=""):
    if isinstance(o, dict):
        for k in list(o.keys()):
            if k.lower() in ("wificonfig", "password", "passphrase", "ssid", "psk"):
                o.pop(k, None)
                hit.append(path + "/" + k)
            else:
                walk(o[k], path + "/" + k)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            walk(v, path + "/" + str(i))

walk(d)
if hit:
    plistlib.dump(d, open(p, "wb"))
    print("credenciais removidas de", p, "->", ", ".join(hit))
PY
done

chown -R "$(stat -f%Su /dev/console)" "$OUT" 2>/dev/null

( cd "$DIR" && zip -qry "$ZIP" "repo-$NAME" ) || { echo "falha no zip"; exit 1; }
chown "$(stat -f%Su /dev/console)" "$ZIP" 2>/dev/null

echo
echo "repo: $OUT"
echo "zip:  $ZIP  ($(du -h "$ZIP" | awk '{print $1}'))"
echo
echo "conteudo:"
( cd "$OUT" && find . -maxdepth 2 -type d | sort | head -20 )
echo
echo "verificando que nao sobrou dado sensivel:"
SENS=$(python3 - "$OC/config.plist" <<'PY'
import plistlib, sys
g = plistlib.load(open(sys.argv[1], "rb"))["PlatformInfo"]["Generic"]
vals = [str(g.get(k, "")) for k in ("SystemSerialNumber", "MLB", "SystemUUID")]
print(" ".join(v for v in vals if v and v != "PUT-YOUR-OWN"))
PY
)
if [ -n "$SENS" ]; then
	PF=$(mktemp /tmp/sens.XXXXXX)
	printf '%s\n' $SENS > "$PF"
	if grep -rFl -f "$PF" "$OUT" 2>/dev/null; then
		echo "  ATENCAO: dado sensivel encontrado nos arquivos acima"
	else
		echo "  (nenhuma ocorrencia de serial/MLB/UUID)"
	fi
	rm -f "$PF"
else
	echo "  (config sem serial/MLB/UUID para procurar)"
fi
