#!/bin/sh
# greetd's default_session command for the Cave Abode greeter: a bare umbriel
# hosting the Quickshell greeter. When the greeter quits (after handing greetd
# the session to start), umbriel quits too and greetd starts your session.
# CAVE_ABODE_USER comes from /etc/cave-abode/greeter/env (greeter-setup.sh).
set -u
root=/etc/cave-abode
export CAVE_ABODE_GREETER=1
[ -r "$root/greeter/env" ] && . "$root/greeter/env"
export CAVE_ABODE_USER
export XDG_SESSION_TYPE=wayland

exec umbriel -c "$root/greeter/umbriel.toml" -s "$root/greeter/run.sh"
