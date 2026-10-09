#!/bin/sh
# Installs the Cave Abode greeter for greetd. Run from your own session:
#   sudo ~/.local/share/noctalia/plugins/cave-abode/greeter-setup.sh            install, keep noctalia-greeter
#   sudo ~/.local/share/noctalia/plugins/cave-abode/greeter-setup.sh --enable   install and switch greetd to it
#   sudo ~/.local/share/noctalia/plugins/cave-abode/greeter-setup.sh --disable  switch greetd back to noctalia-greeter
#
# The greeter runs as the `greeter` user, which can't read your home, so this:
#  - copies the plugin's Quickshell theme and greeter/ to /etc/cave-abode
#    (run it again after updating the plugin);
#  - creates /var/lib/cave-abode, owned by you, which the plugin service keeps
#    filled with your wallpaper, ~/.face, palette, settings and cultivation;
#  - with --enable / --disable, edits /etc/greetd/config.toml (backed up first).
# Keep a TTY login handy (Ctrl+Alt+F2) the first time you log in through it.
set -eu
src="$(cd "$(dirname "$0")" && pwd)"
conf=/etc/greetd/config.toml
user="${SUDO_USER:?run with sudo from your own session}"
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

set_command() {
    cp -a "$conf" "$conf.bak-cave-abode-$(date +%Y%m%d-%H%M%S)"
    # Replace `command = ...` inside [default_session] only.
    awk -v cmd="$1" '
        /^\[/ { s = ($0 == "[default_session]") }
        s && /^[ \t]*command[ \t]*=/ { print "command = \"" cmd "\""; next }
        { print }
    ' "$conf" > "$conf.new" && mv "$conf.new" "$conf"
    echo "greetd now runs: $1 (from the next time greetd starts its greeter)"
}

if [ "${1:-}" = "--disable" ]; then
    set_command noctalia-greeter-session
    exit 0
fi

command -v quickshell >/dev/null || { echo "quickshell is not installed" >&2; exit 1; }

rm -rf /etc/cave-abode
install -d -m 755 /etc/cave-abode
cp -r "$src/quickshell" "$src/greeter" "$src/LICENSE" /etc/cave-abode/
chmod -R a+rX /etc/cave-abode
chmod 755 /etc/cave-abode/greeter/session.sh /etc/cave-abode/greeter/run.sh
printf 'CAVE_ABODE_USER=%s\n' "$user" > /etc/cave-abode/greeter/env

install -d -m 755 -o "$user" -g "$(id -gn "$user")" /var/lib/cave-abode
# Fill it now rather than waiting for the next sync.
sudo -u "$user" env XDG_RUNTIME_DIR="/run/user/$(id -u "$user")" \
    noctalia msg plugin nafeel/cave-abode:service all sync >/dev/null 2>&1 || true

echo "installed to /etc/cave-abode; /var/lib/cave-abode is kept in sync by the plugin"
if [ "${1:-}" = "--enable" ]; then
    set_command /etc/cave-abode/greeter/session.sh
fi
