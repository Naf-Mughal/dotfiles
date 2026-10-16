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

# umbriel, patched (pkg/umbriel-nafeel-git: keep-alive flips, which the
# shell's frame.pump "touch" setting relies on). Built on the first run and
# again whenever the recipe here is newer than the installed build; it
# replaces a plain umbriel / umbriel-git.
recipe=pkg/umbriel-nafeel-git
built=$(pacman -Qi umbriel-nafeel-git 2>/dev/null | sed -n 's/^Install Date *: //p')
if [[ -z "$built" ]] || [[ $(git log -1 --format=%ct -- "$recipe") -gt $(date -d "$built" +%s) ]]; then
  if [[ "${1:-}" == "--packages" ]] || { read -rp "Build and install the patched umbriel (needs sudo)? [Y/n] " a; [[ "$a" != [nN] ]]; }; then
    if command -v paru >/dev/null; then
      (cd "$recipe" && paru -B --noconfirm .)
    else
      (cd "$recipe" && makepkg -si --noconfirm)
    fi || echo "warning: the patched umbriel didn't build; reset the shell's frame.pump setting to redraw"
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
chmod +x "$HOME"/.local/share/noctalia/plugins/*/bin/* 2>/dev/null || true

# The desktop shell: its own repo. Its installer builds it, wires umbriel's
# autostart, moves an older Noctalia-plugin setup over, and offers the SDDM
# login screen. Rerunning this pulls and upgrades it.
shell="$HOME/.local/share/nafeel-shell"
if [[ -d "$shell/.git" ]]; then
  git -C "$shell" pull --ff-only || echo "warning: couldn't update $shell; upgrading what's there"
else
  if [[ -e "$shell" ]]; then
    mv "$shell" "$shell.bak-dotfiles-$stamp"
    echo "backed up $shell (not a git clone)"
  fi
  git clone https://github.com/Naf-Mughal/nafeel-shell "$shell"
fi
"$shell/install.sh" ${1:+"$1"}

# Boot: no Limine menu on good boots; a boot that fails shows it next time.
read -rp "Install boot recovery (hidden Limine menu, shown after a failed boot; needs sudo)? [y/N] " answer
if [[ "$answer" == [yY] ]]; then
  sudo system/boot-recovery/install.sh
fi

cat <<'EOF'

Done. Remaining manual steps:
  - Log out and pick the Umbriel session (or reboot).
  - Wallpapers are not in the repo: copy ~/Pictures/Wallpapers back yourself.
  - Upgrade the shell later: rerun ./install.sh here, or
    cd ~/.local/share/nafeel-shell && git pull && ./install.sh
EOF
