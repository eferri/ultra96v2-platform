#!/bin/bash
set -eu
set -o pipefail

DIR="$(git rev-parse --show-toplevel)"
SDDEV="/dev/sda"

BOOTFS="$DIR/build-sw/mount_bootfs"
ROOTFS="$DIR/build-sw/mount_rootfs"

PLATFORM="ultra96v2"

function eject_sd {
    echo "Syncing..."
    sync

    echo "Unmounting..."
    sudo umount "$BOOTFS" || true

    echo "Unmounting..."
    sudo umount "$ROOTFS" || true

    echo "Ejecting..."
    sudo eject ${SDDEV}
}


function unmount_sd {
    echo "Unmounting..."
    sync

    sudo umount "$BOOTFS"
    sudo umount "$ROOTFS"
}

function mount_sd {
    echo "Mounting..."
    sync

    sudo mkdir -p "$BOOTFS" || true
    if ! mountpoint -q "$BOOTFS"; then
        sudo mount "${SDDEV}1" "$BOOTFS"
    fi

    sudo mkdir -p "$ROOTFS" || true
    if ! mountpoint -q "$ROOTFS"; then
        sudo mount "${SDDEV}2" "$ROOTFS"
    fi
}

function partition_sd {
    echo "Unmounting..."
    sudo umount "$ROOTFS" || true

    echo "Removing existing partitions ..."
    sudo parted -s ${SDDEV} rm 1 || true
    sudo parted -s ${SDDEV} rm 2 || true

    echo "Partitioning drive ..."
    sudo parted -s "${SDDEV}" -a optimal mklabel msdos \
            mkpart primary fat32 4MB 1000MB \
            mkpart primary ext4  1000MB 100%
    partprobe

    sudo mkfs.vfat -F 32 "${SDDEV}1"
    sudo mkfs.ext4 -qF "${SDDEV}2"
}

function install {
    partition_sd
    mount_sd

    echo "Installing boot files... $@"
    sudo cp -r "$@" "$BOOTFS"

    echo "Installing rootfs..."
    sudo tar -I pigz -xvf build-sw/rootfs.tar.gz -C "$ROOTFS"

    sudo rm -f "$ROOTFS"/.dockerenv

    eject_sd
}

function usage () {
    echo "Usage: $0 MODE [FILE] [FILE] ...."
    echo "Modes: install <files> : mount, re-partition SD, install application files and rootfs and eject"
    echo "       eject           : eject SD card"
    echo "       mount           : mount SD card"
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
    mount)
        mount_sd
        ;;
    unmount)
        unmount_sd
        ;;
    partition)
        partition_sd
        ;;

    *)
        usage
        ;;
esac
