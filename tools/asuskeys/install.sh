#!/bin/sh
# Install asuskeysd + asusbl for the current user.
# Run ./build.sh first.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/bin"
AGENT="$HOME/Library/LaunchAgents/com.tiriba.asuskeys.plist"

if [ ! -x "$BIN/asuskeysd" ] || [ ! -x "$BIN/asusbl" ]; then
    echo "binaries missing - run ./build.sh first" >&2
    exit 1
fi

mkdir -p "$HOME/Applications/AsusKeys" "$HOME/.config/asuskeys" "$HOME/Library/LaunchAgents"
cp "$BIN/asuskeysd" "$HOME/Applications/AsusKeys/asuskeysd"
cp "$BIN/asusbl" "$HOME/.config/asuskeys/asusbl"
cp "$DIR/kbd-backlight.sh" "$HOME/.config/asuskeys/kbd-backlight.sh"
chmod +x "$HOME/Applications/AsusKeys/asuskeysd" "$HOME/.config/asuskeys/asusbl" "$HOME/.config/asuskeys/kbd-backlight.sh"

sed "s|@HOME@|$HOME|g" "$DIR/com.tiriba.asuskeys.plist" > "$AGENT"

launchctl bootout "gui/$(id -u)/com.tiriba.asuskeys" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT"

cat <<EOF
installed.

Next: System Settings > Privacy & Security > Accessibility
      enable $HOME/Applications/AsusKeys/asuskeysd
      (permission is per binary; rebuilding revokes it)

Log:  $HOME/Library/Logs/asuskeysd.log
Test: $HOME/.config/asuskeys/asusbl +   # level 0..3
EOF
