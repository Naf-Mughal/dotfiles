#!/usr/bin/env bash
# Put this repo's configs in place on a fresh CachyOS install.
#   ./install.sh            copy configs (existing files are backed up as *.bak-dotfiles-<time>)
#   ./install.sh --packages also install packages first (pacman + paru)
set -euo pipefail
cd "$(dirname "$0")"
stamp=$(date +%Y%m%d-%H%M%S)

if [[ "${1:-}" == "--packages" ]]; then
  sudo pacman -S --needed - < packages.txt
  if command -v paru >/dev/null; then
    paru -S --needed - < packages-aur.txt
  else
    echo "paru not found; install these from the AUR yourself:"; cat packages-aur.txt
  fi
fi

backup() {
  if [[ -e "$1" ]]; then
    cp -a "$1" "$1.bak-dotfiles-$stamp"
    echo "backed up $1"
  fi
}

grep -vE '^\s*(#|$)' files.txt | while read -r path; do
  dest="$HOME/$path"
  if [[ ! -e "home/$path" ]]; then
    echo "skip (not in repo): $path"
    continue
  fi
  mkdir -p "$(dirname "${dest%/}")"
  if [[ "$path" == */ ]]; then
    backup "${dest%/}"
    rsync -a "home/$path" "$dest"
  else
    backup "$dest"
    rsync -a "home/$path" "$dest"
  fi
done
chmod +x "$HOME"/.local/bin/greeter-numlock-on "$HOME"/.local/share/noctalia/plugins/*/bin/* 2>/dev/null || true

# Login screen: greetd runs noctalia-greeter; greeter.toml carries numlock = true.
echo
read -rp "Install greeter config and enable greetd (needs sudo)? [y/N] " answer
if [[ "$answer" == [yY] ]]; then
  sudo install -Dm644 system/greetd/config.toml /etc/greetd/config.toml
  sudo install -d -m750 -o greeter -g greeter /var/lib/noctalia-greeter
  sudo install -m640 -o greeter -g greeter system/noctalia-greeter/greeter.toml /var/lib/noctalia-greeter/greeter.toml
  # Num Lock on at the login screen, even if the copy above was synced without it.
  sudo "$HOME/.local/bin/greeter-numlock-on"
  sudo systemctl enable greetd
fi

# Boot: no Limine menu on good boots; a boot that fails shows it next time.
read -rp "Install boot recovery (hidden Limine menu, shown after a failed boot; needs sudo)? [y/N] " answer
if [[ "$answer" == [yY] ]]; then
  sudo system/boot-recovery/install.sh
fi

cat <<'EOF'

Done. Remaining manual steps:
  - Log out and pick the Umbriel session (or reboot).
  - Wallpapers are not in the repo: copy ~/Pictures/Wallpapers back yourself.
  - My plugins (nafeel/*) are copied to ~/.local/share/noctalia/plugins; the
    community ones listed in settings.toml are fetched when Noctalia starts.
    If one is missing, enable it in Settings → Plugins.
  - Wallpaper Palette sets up its Python venv on first start (needs network once).
EOF
