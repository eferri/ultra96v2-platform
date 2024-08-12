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
<! echo "upload $PFM_DIR/rootfs/netplan.yml /etc/netplan/99_config.yaml"

rm /etc/resolv.conf
rm /usr/sbin/policy-rc.d
rm-rf /boot

chmod 0600 /etc/netplan/99_config.yaml

tar-out / ./build-sw/rootfs.tar.gz compress:gzip
