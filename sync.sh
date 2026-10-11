#!/usr/bin/env bash
# Copy the live configs listed in files.txt into this repo, then show what changed.
# Usage: ./sync.sh            (then review, commit and push)
set -euo pipefail
cd "$(dirname "$0")"

excludes=(--exclude='*.bak*' --exclude='*.pre-*' --exclude='__pycache__/' --exclude='native/build/')

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

# Greeter files are root-only; refresh them when sudo is already unlocked.
if sudo -n true 2>/dev/null; then
  sudo cat /var/lib/noctalia-greeter/greeter.toml > system/noctalia-greeter/greeter.toml
  cp /etc/greetd/config.toml system/greetd/config.toml
else
  echo "note: run 'sudo -v' first to also refresh system/ (greeter config)"
fi

git status --short
