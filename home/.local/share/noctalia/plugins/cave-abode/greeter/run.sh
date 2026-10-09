#!/bin/sh
# Runs inside the greeter's umbriel (see session.sh).
quickshell -p /etc/cave-abode/quickshell/Greeter.qml
umbriel msg session-quit
