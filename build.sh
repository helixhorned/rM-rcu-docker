#!/bin/sh

source_rcu_tar="$1"

IMAGE_NAME=remarkable-rcu
MIN_RCU_VERSION=r2020-003

TEMP_BASE_DIR=/dev/shm
TEMP_DIR_TEMPLATE="$TEMP_BASE_DIR/rM-rcu-docker-XXXXXX"

if [ -z "$source_rcu_tar" ]; then
    echo "Usage: $0 <RCU source archive>"
    echo
    echo " Creates a Docker image with the reMarkable Connection Utility extracted"
    echo " from the provided archive and all of its runtime dependencies installed."
    echo
    echo " The image is named '$IMAGE_NAME:<tag>', where '<tag>' is e.g. '$MIN_RCU_VERSION'."
    echo
    echo " RCU can be obtained from the utility author's web page:"
    echo "  http://www.davisr.me/projects/rcu/"
    echo " Its source archives are named like 'source-rcu-r2020-003.tar.gz'."
    echo
    exit 1
fi

if [ ! -f "$source_rcu_tar" ]; then
    echo "ERROR: '$source_rcu_tar' is not a regular file." 1>&2
    exit 2
fi

## --------------------

echo "Checking SHA256 against known versions of RCU..." 1>&2

source_sha256=$(sha256sum "$source_rcu_tar" | sed 's/ .*//')

IMAGE_TAG=
STRIP_DIR=
if [ x"$source_sha256" = x"efee9c7843b1d8ebcd7c3f4ad4b9b31e72dc5fa7793549532e4e17c518291409" ]; then
    IMAGE_TAG=r2020-003
    STRIP_DIR=source-rcu-$IMAGE_TAG
fi

if [ -z "$IMAGE_TAG" ]; then
    echo "ERROR: Unrecognized RCU source archive. (Currently, only $MIN_RCU_VERSION is supported.)" 1>&2
    exit 3
fi

if ! tempDir=$(mktemp -d "$TEMP_DIR_TEMPLATE"); then
    echo "ERROR: failed creating temporary directory." 1>&2
    exit 100
fi

if ! source_rcu_tar=$(realpath "$source_rcu_tar"); then
    echo "ERROR: failed canonicalizing file name." 1>&2
    exit 101
fi

thisDir="$(pwd)"
cd "$tempDir" || (echo "INTERNAL ERROR" 1>&2; exit 200)

## --------------------

echo "Extracting from source archive..." 1>&2

tar xf "$source_rcu_tar" --strip-components=1 "$STRIP_DIR/rcu/"

fullName="$IMAGE_NAME":"$IMAGE_TAG"
echo "Building Docker image '$fullName'..." 1>&2

export DOCKER_BUILDKIT=1
exec docker build \
       --tag "$fullName" \
       --build-arg USER="$USER" --build-arg UID="$(id -u)" \
       -f "$thisDir/Dockerfile" \
       .
