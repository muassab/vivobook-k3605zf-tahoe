#!/bin/sh
# bt-recover — restart bluetoothd to restore BLE HID reports after reconnect.
# Symptom: BLE mouse/keyboard link is up but no input events (MT7902, macOS 26).
set -e

if [ "$(id -u)" -eq 0 ]; then
    launchctl kickstart -k system/com.apple.bluetoothd
else
    osascript -e 'do shell script "launchctl kickstart -k system/com.apple.bluetoothd" with administrator privileges'
fi

i=0
while [ "$i" -lt 30 ]; do
    sleep 1
    if hidutil list 2>/dev/null | grep -q "Bluetooth Low Energy"; then
        echo "HID Bluetooth presente após ${i}s"
        blueutil --connected 2>/dev/null | head -5 || true
        exit 0
    fi
    i=$((i + 1))
done

echo "HID Bluetooth não apareceu em 30s" >&2
exit 1
