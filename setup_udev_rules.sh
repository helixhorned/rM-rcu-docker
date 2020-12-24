#!/bin/sh

if [ x"$(id -u)" = x'0' ]; then
    echo "ERROR: this script should be run as non-root." >&2
    exit 1
fi

if ! gid="$(id -g)"; then
    echo "ERROR: failed obtaining group ID." >&2
    exit 2
fi

rulesDir=/etc/udev/rules.d

if [ ! -d "$rulesDir" ]; then
    echo "ERROR: missing udev rules directory '$rulesDir'." >&2
    exit 3
fi

# TODO: allow/auto-detect 'doas'?
sudo=sudo

if ! $sudo udevadm control --ping; then
    echo "ERROR: systemd-udevd daemon must be running. (Failed pinging it.)" >&2
    exit 4
fi

rulesBase="50-remarkable.rules"
srcRulesFile="./${rulesBase}.in"
dstRulesFile="$rulesDir/$rulesBase"

if ! sed "s/@GROUP@/$gid/g" "$srcRulesFile" | $sudo tee "$dstRulesFile" > /dev/null; then
    echo "ERROR: failed installing '$dstRulesFile'" >&2
    exit 5
fi

if ! $sudo udevadm control --reload; then
    echo "ERROR: failed signaling systemd-udevd to reload the rules files." >&2
    exit 5
fi

echo "Successfully set up '$dstRulesFile' for RCU backup functionality."
