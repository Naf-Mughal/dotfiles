#!/usr/bin/env bash
# Windows-style boot recovery for Limine:
#   good boots      -> next boot is instant, no menu
#   any failed boot -> next power-on shows the menu (10 s, then the default kernel)
# plus `systemctl reboot --boot-loader-menu=30` to ask for the menu on purpose.
#
#   sudo ./install.sh
set -euo pipefail
cd "$(dirname "$0")"

((EUID == 0)) || { echo "run with sudo" >&2; exit 1; }

conf=/boot/limine.conf
efi=/boot/EFI/limine/limine_x64.efi
var=/sys/firmware/efi/efivars/LoaderConfigTimeoutOneShot-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f

[[ -f $conf ]] || { echo "no $conf" >&2; exit 1; }

# If a hash of limine.conf is enrolled in the EFI binary, editing the file
# would make Limine refuse to boot. It isn't on this machine
# (ENABLE_ENROLL_LIMINE_CONFIG is unset), but check rather than assume.
if [[ -f $efi ]] && grep -qa "$(b2sum "$conf" | cut -d' ' -f1)" "$efi"; then
    echo "limine.conf's hash is enrolled in $efi; not editing it." >&2
    exit 1
fi

# limine.conf: what a boot WITHOUT the one-shot does, i.e. after a failure.
cp -a "$conf" "$conf.bak-boot-recovery"
sed -i 's/^timeout:.*/timeout: 10/; s/^remember_last_entry:.*/remember_last_entry: no/; /^quiet:/d' "$conf"
grep -q '^timeout:' "$conf" || sed -i '1i timeout: 10' "$conf"
echo "limine.conf (backup: $conf.bak-boot-recovery):"
head -3 "$conf" | sed 's/^/  /'

install -Dm755 limine-boot-ok /usr/local/bin/limine-boot-ok
install -Dm644 limine-boot-ok.service /etc/systemd/system/limine-boot-ok.service
install -Dm644 limine-boot-ok.timer /etc/systemd/system/limine-boot-ok.timer
install -Dm755 limine-boot-ok.sleep /etc/systemd/system-sleep/limine-boot-ok
systemctl daemon-reload
systemctl enable limine-boot-ok.timer

# This boot reached a desktop, so arm the next one now, and check the
# variable is exactly what Limine matches: UTF-16 "menu-disabled" + NUL
# (28 bytes) after the 4-byte attributes.
rm -f /run/limine-boot-ok
/usr/local/bin/limine-boot-ok
if [[ -e /run/limine-boot-ok && -e $var && $(stat -c %s "$var") -eq 32 ]] &&
    [[ $(tail -c +5 "$var" | iconv -f UTF-16LE -t UTF-8 | tr -d '\0') == menu-disabled ]]; then
    echo "OK: next boot is instant; a boot that fails to reach the desktop brings the menu back."
else
    echo "WARNING: the one-shot variable isn't in the form Limine expects;" >&2
    echo "the menu will show on every boot (safe, just not hidden)." >&2
    [[ -e $var ]] && od -c "$var" >&2
    exit 1
fi
