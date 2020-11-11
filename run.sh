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
OutDirSuffix="Documents/rM-rcu-docker-out"

mkdir -p "$HOME/$OutDirSuffix"

# TODO: make this configurable somehow?
MountArgs=( \
  -v "$HOME/Documents:$guestHome/Documents:ro" \
  -v "$HOME/$OutDirSuffix:$guestHome/$OutDirSuffix" \
)

if [ $runShell = true ]; then
    EntryPointArgs=()
    TrailingArgs=()
else
    EntryPointArgs=(--entrypoint python3)
    TrailingArgs=(-B main.py)
fi

## ----------

DavisrConfigDirSuffix=".config/davisr"
RcuDataDirSuffix=".local/share/davisr/rcu"

# Make sure the RCU data directory and the directory containing rcu.conf is owned by us
# instead of root if it were created by Docker.
mkdir -p "$HOME/$RcuDataDirSuffix"
mkdir -p "$HOME/$DavisrConfigDirSuffix"

rcuConf="$HOME/$DavisrConfigDirSuffix/rcu.conf"

if [ -e "$rcuConf" ]; then
    # Allow only a default data directory since otherwise, we need to extract the path,
    # which we prefer to keep under our control for containerization reasons.
    #
    # Notes:
    #  - This is still hacky: e.g, we don't check that the line belongs to the [main] section.
    #  - Let's hope we don't run into character quoting issues with unusual $HOME directories.
    #    (for example: the configuration file representing unusual characters in any other
    #     than their literal form; the directory name containing a newline, ...)
    expectedSharePathLine="share_path=$HOME/$RcuDataDirSuffix"
    actualLine=$(grep --fixed-strings "$expectedSharePathLine" "$rcuConf")
    # shellcheck disable=SC2181
    if [[ $? -ne 0 || x"$actualLine" != x"$expectedSharePathLine" ]]; then
        echo "ERROR: in '$rcuConf':" 1>&2
        echo "  'share_path' must point to '$HOME/$RcuDataDirSuffix'." 1>&2
        echo "  Using a custom data directory is not supported by rM-rcu-docker." 1>&2
        exit 2
    fi
fi

docker run -it --rm \
       --net=host \
       --hostname=rM-rcu \
       --add-host='remarkable:10.11.99.1' \
       -e DISPLAY \
       -v "$HOME/.Xauthority:$guestHome/.Xauthority:ro" \
       -v "$HOME/$RcuDataDirSuffix:$guestHome/$RcuDataDirSuffix" \
       -v "$HOME/$DavisrConfigDirSuffix:$guestHome/$DavisrConfigDirSuffix" \
       "${MountArgs[@]}" \
       "${EntryPointArgs[@]}" \
       remarkable-rcu:$DEFAULT_RCU_VERSION \
       "${TrailingArgs[@]}"
