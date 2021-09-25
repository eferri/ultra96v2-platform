#!/usr/bin/env bash
set -eu
set -o pipefail

DIR="$(git rev-parse --show-toplevel)"
SDDEV="/dev/sda"
BOOTFS="$DIR/build-hw/mount"
PLATFORM="ultra96v2"

function eject_sd {
    echo "Syncing..."
    sync

    echo "Unmounting..."
    sudo umount "$BOOTFS" || true

    echo "Ejecting..."
    sudo eject ${SDDEV}
}

function erase_sd {
    echo "Erasing bootfs ..."
    sudo rm -rf "$BOOTFS/*" "$BOOTFS/.*"
}

function mount_sd {
    echo "Mounting..."
    sync

    sudo mkdir -p "$BOOTFS" || true
    if ! mountpoint -q "$BOOTFS"; then
        sudo mount "${SDDEV}1" "$BOOTFS"
    fi
}

function partition_sd {
    echo "Unmounting..."
    sudo umount "$BOOTFS" || true

    echo "Removing existing partitions ..."
    sudo parted -s ${SDDEV} rm 1 || true

    echo "Partitioning drive ..."
    sudo parted -s "${SDDEV}" -a optimal mklabel msdos \
            mkpart primary fat32 4MB 1000MB
    partprobe

    sudo mkfs.vfat -F 32 "${SDDEV}1"
}

function install {
    partition_sd
    mount_sd
    echo "Installing application... $@"
    sudo cp "$@" "$BOOTFS"
    eject_sd
}

function usage () {
    echo "Usage: $0 MODE [FILE] [FILE] ...."
    echo "Modes: all <files>     : mount, erase SD card, install image and eject"
    echo "       install <files> : mount, install given files to second SD partition and eject"
    echo "       eject           : eject SD card"
    echo "       erase           : erase SD card"
    echo "       mount           : mount SD card"
    echo "       boot <files>    : write boot and application files to first SD card partition"
    echo "       partition       : partition SD card"
    exit 1
}

if [ "$#" -eq 0 ]; then
    usage
    exit 1
fi

case "$1" in
    all|install)
        shift
        if [ "$#" -lt 1 ]; then
            echo "No files to install specified"
            exit 1
        fi
        install "$@"
        ;;
    eject)
        eject_sd
        ;;
    erase)
        erase_sd
        ;;
    mount)
        mount_sd
        ;;
    partition)
        partition_sd
        ;;

    *)
        usage
        ;;
esac
