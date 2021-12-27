#!/bin/bash

DavisrConfigDirSuffix=".config/davisr"
OurConfFile="$HOME/$DavisrConfigDirSuffix/rcu-docker.conf"

runShell=
if [ -z "$1" ]; then
    runShell=false
elif [ x"$1" = x"--shell" ]; then
    runShell=true
fi

if [ -z "$runShell" ]; then
    echo "Usage: $0 [--shell|--help]"
    echo
    echo "  A configuration file '$OurConfFile'"
    echo "  may be created manually containing lines of the form"
    echo "      mount-ro=<directory-suffix>"
    echo "  or"
    echo "      mount-rw=<directory-suffix>"
    echo "  (without leading whitespace) specifying directories under the"
    echo "  host home directory to be mounted into the container."
    echo "  For each <directory-suffix>, the path '\$HOME/<directory-suffix>'"
    echo "  must be canonical: redundant slashes, symlinks, and '.' or '..'"
    echo "  as components are not allowed."
    echo
    # TODO: allow read-only '.' (that is, mapping the whole home directory)?
    exit 1
fi

## ----------

# TODO: add an argument once we support more than one version.
DEFAULT_RCU_VERSION=r2021-002

guestHome="/home/$USER"

MountArgs=()

if [ -f "$OurConfFile" ]; then
    mountDirSuffixes=()
    mountKinds=()

    lines=()
    mapfile -t lines < "$OurConfFile"
    lineCount="${#lines[@]}"
    for ((i=0; i < lineCount; i++)); do
        line="${lines[$i]}"
        location="$OurConfFile:$((i+1))"
        ErrorSuffix="See '$0 --help' for the expected format."

        if [[ ! "$line" =~ ^mount-r[ow]=.+$ ]]; then
            echo "ERROR: $location: malformed line." 1>&2
            echo "       $ErrorSuffix" 1>&2
            exit 1
        fi

        kind="${line:6:2}"
        dirSuffix="${line:9}"

        hostDir="$HOME/$dirSuffix"
        realHostDir="$(realpath --quiet -e "$hostDir")"
        if [ x"$realHostDir" != x"$hostDir" ]; then
            echo "ERROR: $location: invalid directory suffix." 1>&2
            echo "       (Does not point to an existing directory or is not canonical.)" 1>&2
            echo "       $ErrorSuffix" 1>&2
            exit 1
        fi

        case "$kind" in
            ro|rw)
                n=${#mountDirSuffixes[@]}
                mountDirSuffixes[$n]="$dirSuffix"
                mountKinds[$n]="$kind"
                ;;
        esac
    done

    n=${#mountDirSuffixes[@]}

    if [ "$n" -ne 0 ]; then
        echo "INFO: Mounts from '$HOME' into container '$guestHome':"
        for ((i=0; i < n; i++)) do
            dirSuffix="${mountDirSuffixes[$i]}"
            kind="${mountKinds[$i]}"
            echo "  $kind: $dirSuffix"

            j="$((2*i))"
            k="$((2*i+1))"
            MountArgs[$j]='-v'
            MountArgs[$k]="$HOME/$dirSuffix:$guestHome/$dirSuffix:$kind"
        done
    fi
fi

if [ $runShell = true ]; then
    EntryPointArgs=()
    TrailingArgs=()
else
    EntryPointArgs=(--entrypoint python3)
    TrailingArgs=(-B main.py)
fi

## ----------

RcuDataDirSuffix=".local/share/davisr/rcu"

# Make sure the RCU data directory and the directory containing rcu.conf is owned by us
# instead of root if it was created by Docker.
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

# Make sure that the device node for the rM in recovery mode -- used for the backup
# functionality of RCU -- can be accessed. The mount and rule are overly broad, but unless
# the system has set up additional udev rules, the only device node with a non-root (group)
# owner should be that particular one, thanks to the setup of 'setup_udev_rules.sh'.
#
# Linux's 'Documentation/admin-guide/devices.txt' lists the device major number as
#  "189 char	USB serial converters - alternate devices".
UsbAccessArgs=( \
  -v '/dev/bus/usb:/dev/bus/usb' \
  --device-cgroup-rule 'c 189:* rw' \
)

exec docker run -it --rm \
       --net=host \
       --hostname=rM-rcu \
       --add-host='remarkable:10.11.99.1' \
       -e DISPLAY \
       "${UsbAccessArgs[@]}" \
       -v "$HOME/.Xauthority:$guestHome/.Xauthority:ro" \
       -v "$HOME/$RcuDataDirSuffix:$guestHome/$RcuDataDirSuffix" \
       -v "$HOME/$DavisrConfigDirSuffix:$guestHome/$DavisrConfigDirSuffix" \
       "${MountArgs[@]}" \
       "${EntryPointArgs[@]}" \
       remarkable-rcu:$DEFAULT_RCU_VERSION \
       "${TrailingArgs[@]}"
