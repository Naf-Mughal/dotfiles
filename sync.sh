#!/usr/bin/env bash
# Copy the live configs listed in files.txt into this repo, then show what changed.
# Usage: ./sync.sh            (then review, commit and push)
set -euo pipefail
cd "$(dirname "$0")"

excludes=(--exclude='*.bak*' --exclude='*.pre-*' --exclude='__pycache__/' --exclude='native/build/' --exclude='/palette-venv/' --exclude='/templates/')

grep -vE '^\s*(#|$)' files.txt | while read -r path; do
  src="$HOME/$path"
  if [[ ! -e "$src" ]]; then
    echo "skip (missing): $path"
    continue
  fi
  mkdir -p "home/$(dirname "$path")"
  if [[ "$path" == */ ]]; then
    rsync -a --delete "${excludes[@]}" "$src" "home/$path"
  else
    rsync -a "$src" "home/$path"
  fi
done

# The login screen: SDDM running the shell's lock (bin/nafeel-greeter
# install writes this; the theme itself is built from the shell plugin).
mkdir -p system/sddm
cp /etc/sddm.conf.d/10-nafeel.conf system/sddm/10-nafeel.conf 2>/dev/null || true

git status --short
