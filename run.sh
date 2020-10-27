#!/bin/bash

runShell=
if [ -z "$1" ]; then
    runShell=false
elif [ x"$1" = x"--shell" ]; then
    runShell=true
fi

if [ -z "$runShell" ]; then
    echo "Usage: $0 [--shell]"
    exit 1
fi

## ----------

# TODO: add an argument once we support more than one version.
DEFAULT_RCU_VERSION=r2020-003

guestHome="/home/$USER"

# TODO: make this configurable somehow?
MountArgs=( \
  -v "$HOME/Documents:$guestHome/Documents:ro" \
)

if [ $runShell = true ]; then
    EntryPointArgs=()
    TrailingArgs=()
else
    EntryPointArgs=(--entrypoint python3)
    TrailingArgs=(-B main.py)
fi

## ----------

docker run -it --rm \
       --net=host \
       --hostname=rM-rcu \
       --add-host='remarkable:10.11.99.1' \
       -e DISPLAY \
       -v "$HOME/.Xauthority:$guestHome/.Xauthority:ro" \
       -v "$HOME/.local/share/davisr/rcu:$guestHome/.local/share/davisr/rcu" \
       "${MountArgs[@]}" \
       "${EntryPointArgs[@]}" \
       remarkable-rcu:$DEFAULT_RCU_VERSION \
       "${TrailingArgs[@]}"
