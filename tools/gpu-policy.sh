#!/bin/sh
# Escreve a policy de GPU do NullMoth (/Library/GPUBundles/nvmtl-gpu-policy.txt).
# Uso: sudo sh ~/mtk/gpu-policy.sh "mode nvidia" ["igpu Safari"] ["nvidia Blender"]
# Sem argumentos: mostra a policy atual.
set -u
P=/Library/GPUBundles/nvmtl-gpu-policy.txt

if [ $# -eq 0 ]; then
	if [ -f "$P" ]; then
		echo "== $P"
		cat "$P"
	else
		echo "(sem arquivo: default mode nvidia)"
	fi
	exit 0
fi

[ -d /Library/GPUBundles ] || { echo "sem /Library/GPUBundles (driver nao instalado)"; exit 1; }

if [ -f "$P" ]; then
	cp "$P" "$P.bak-$(date +%Y%m%d-%H%M%S)"
fi

: > "$P"
for line in "$@"; do
	printf '%s\n' "$line" >> "$P"
done
chmod 644 "$P"

echo "== $P"
cat "$P"
echo
echo "reabrir o app alvo para valer (a policy e lida no inicio do processo)"
