#!/bin/bash

source_rcu_tar="$1"

BASE_IMAGE_PREFIX=ubuntu:jammy
BASE_IMAGE_DATE=-20231211.1
BASE_IMAGE="${BASE_IMAGE_PREFIX}${BASE_IMAGE_DATE}"

IMAGE_NAME=remarkable-rcu
MAX_RCU_VERSION=d2023-001l

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
    echo "  - rcu-d2023.001l-source.tar.gz"
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
if [ "$source_sha256" = "efee9c7843b1d8ebcd7c3f4ad4b9b31e72dc5fa7793549532e4e17c518291409" ]; then
    IMAGE_TAG=r2020-003
    STRIP_DIR=source-rcu-$IMAGE_TAG
elif [ "$source_sha256" = "45cdaf1771798308cf15f0f8996d6e1562d5d060fe4c15dc406ee913a6b24fea" ]; then
    IMAGE_TAG=r2021-001
elif [ "$source_sha256" = "1c0ad2da79d5f15ccf920c479c4fa11ce1dcef88c38d897dab09c1ee34b808aa" ]; then
    IMAGE_TAG=r2021-002
elif [ "$source_sha256" = "695d1ee5404ad88b683544d053d27703ff85f63ac0c96ac4edec4777f928f8e8" ]; then
    IMAGE_TAG=d2023-001l
fi

if [ -z "$IMAGE_TAG" ]; then
    echo "ERROR: Unrecognized RCU source archive." 1>&2
    exit 3
fi

version_year_seq=${IMAGE_TAG:1:8}
version_year_seq=${version_year_seq/-/}

if [[ "$IMAGE_TAG" == 'r2020-003' || "$IMAGE_TAG" == 'r2021-001' ]]; then
    additional_packages="$additional_packages python3-pdfrw"
# else: bundled by RCU.
fi

if [ "$version_year_seq" -ge 2023001 ]; then
    additional_packages="$additional_packages python3-pdfminer python3-pikepdf python3-protobuf python3-six"
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
if [ -n "$STRIP_DIR" ]; then
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
if [ "$machine" = 'aarch64' ]; then
    imx_usb_sha256=0de9a50ae860bbca1f433a0b3b69a817a4a5c9f07463cf39b2a296eb8d525efe
elif [ "$machine" = 'x86_64' ]; then
    imx_usb_sha256=b2ddf8f0e4687f5a067632842abf51a46ebbbe4c136eb9d3e44bafafa2412804
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
