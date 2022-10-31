#!/bin/bash

source_rcu_tar="$1"

BASE_IMAGE_PREFIX=ubuntu:jammy
BASE_IMAGE_DATE=-20221020
BASE_IMAGE="${BASE_IMAGE_PREFIX}${BASE_IMAGE_DATE}"

IMAGE_NAME=remarkable-rcu
MIN_RCU_VERSION=r2020-003
MAX_RCU_VERSION=r2021-002

TEMP_BASE_DIR=/dev/shm
TEMP_DIR_TEMPLATE="$TEMP_BASE_DIR/rM-rcu-docker-XXXXXX"

if [ -z "$source_rcu_tar" ]; then
    echo "Usage: $0 <RCU source archive>"
    echo
    echo " Creates a Docker image with the reMarkable Connection Utility extracted"
    echo " from the provided archive and all of its runtime dependencies installed."
    echo
    echo " The image is based on '$BASE_IMAGE' and named"
    echo " '$IMAGE_NAME:<tag>', where '<tag>' is e.g. '$MAX_RCU_VERSION'."
    echo
    echo " RCU can be obtained from the utility author's web page:"
    echo "  http://www.davisr.me/projects/rcu/"
    echo
    echo " Source archives for RCU versions supported by this script are named:"
    echo "  - source-rcu-r2020-003.tar.gz"
    echo "  - rcu-r2021.001-source.tar.gz"
    echo "  - rcu-r2021.002-source.tar.gz"
    echo " The actual version used is determined by a check on the SHA256 of the"
    echo " passed archive file, though."
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

additional_packages="python3-paramiko"
additional_packages="$additional_packages python3-pil"  # r2021.001
additional_packages="$additional_packages python3-certifi"  # r2021.002

IMAGE_TAG=
STRIP_DIR=
if [ x"$source_sha256" = x"efee9c7843b1d8ebcd7c3f4ad4b9b31e72dc5fa7793549532e4e17c518291409" ]; then
    IMAGE_TAG=r2020-003
    STRIP_DIR=source-rcu-$IMAGE_TAG
elif [ x"$source_sha256" = x"45cdaf1771798308cf15f0f8996d6e1562d5d060fe4c15dc406ee913a6b24fea" ]; then
    IMAGE_TAG=r2021-001
elif [ x"$source_sha256" = x"1c0ad2da79d5f15ccf920c479c4fa11ce1dcef88c38d897dab09c1ee34b808aa" ]; then
    IMAGE_TAG=r2021-002
fi

if [ -z "$IMAGE_TAG" ]; then
    echo "ERROR: Unrecognized RCU source archive. (Supported: releases between ${MIN_RCU_VERSION} and ${MAX_RCU_VERSION}.)" 1>&2
    exit 3
fi

if [[ x"$IMAGE_TAG" == x'r2020-003' || x"$IMAGE_TAG" == x'r2021-001' ]]; then
    additional_packages="$additional_packages python3-pdfrw"
# else: bundled by RCU.
fi

if ! tempDir=$(mktemp -d "$TEMP_DIR_TEMPLATE"); then
    echo "ERROR: failed creating temporary directory." 1>&2
    exit 100
fi

if ! source_rcu_tar=$(realpath "$source_rcu_tar"); then
    echo "ERROR: failed canonicalizing file name." 1>&2
    exit 101
fi

# Will be used for the path to the Dockerfile:
thisDir="$(pwd)"

if ! cd "$tempDir"; then
    echo "INTERNAL ERROR: failed changing into temporary directory." 1>&2
    exit 201
fi

## --------------------

echo "Extracting from source archive..." 1>&2

# Do not extract imx_usb binaries since we will be building our own.
# Keep 'imx_usb.conf' though.
tarOpts=("--exclude=*/recovery_os_build/imx_usb.[flmsw]*")
if [ ! -z "$STRIP_DIR" ]; then
    tarOpts[1]="--strip-components=1"
    tarOpts[2]="$STRIP_DIR/rcu/"
fi
if ! tar xf "$source_rcu_tar" "${tarOpts[@]}"; then
    echo "ERROR: failed extracting RCU source code." 1>&2
    exit 102
fi

fullName="$IMAGE_NAME":"$IMAGE_TAG"
echo "Building Docker image '$fullName'..." 1>&2

machine=$(uname -m)
if [ x"$machine" = x'aarch64' ]; then
    imx_usb_sha256=49417f47525c10c7abf0e6c7f8ea03793211922660bbc47811991a9a70e29cd4
elif [ x"$machine" = x'x86_64' ]; then
    imx_usb_sha256=765bbdda5f717015f1be809613eac81887deb59e6d1bff734bbade1680ca8b96
else
    echo "WARNING: omitting SHA256 check for 'imx_usb' binary on $machine machine." 1>&2
    echo "INFO: consider contacting the rM-rcu-docker maintainer <dev@helixhorned.de>." 1>&2
    imx_usb_sha256='.'
fi

export DOCKER_BUILDKIT=1
exec docker build \
       --tag "$fullName" \
       --build-arg BASE_IMAGE="$BASE_IMAGE" \
       --build-arg ADDITIONAL_PACKAGES="$additional_packages" \
       --build-arg USER="$USER" --build-arg UID="$(id -u)" \
       --build-arg IMX_USB_SHA256="$imx_usb_sha256" \
       -f "$thisDir/Dockerfile" \
       .
