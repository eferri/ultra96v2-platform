#!/usr/bin/guestfish -f

add-drive ./build-sw/qemu.img format:raw

launch

part-disk /dev/sda mbr
mkfs ext4 /dev/sda1
mount /dev/sda1 /

tar-in ./build-sw/docker_rootfs.tar /
rm /.dockerenv

<! echo "upload $PFM_DIR/rootfs/hosts /etc/hosts"
<! echo "upload $PFM_DIR/rootfs/hostname /etc/hostname"

rm /etc/resolv.conf

tar-out / ./build-sw/rootfs.tar.gz compress:gzip
