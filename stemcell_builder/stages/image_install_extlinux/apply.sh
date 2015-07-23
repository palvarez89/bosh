#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image=${work}/${stemcell_image_name}
image_mount_point=${work}/mnt


## unmap the loop device in case it's already mapped
#umount ${image_mount_point}/proc || true
#umount ${image_mount_point}/sys || true
#umount ${image_mount_point} || true
#losetup -j ${disk_image} | cut -d ':' -f 1 | xargs --no-run-if-empty losetup -d
kpartx -dv ${disk_image}

# note: if the above kpartx command fails, it's probably because the loopback device needs to be unmapped.
# in that case, try this: sudo dmsetup remove loop0p1

# Map partition in image to loopback
device=$(losetup --show --find ${disk_image})
add_on_exit "losetup --verbose --detach ${device}"

device_partition=$(kpartx -av ${device} | grep "^add" | cut -d" " -f3)
add_on_exit "kpartx -dv ${device}"

loopback_dev="/dev/mapper/${device_partition}"

# Mount partition
mkdir -p ${image_mount_point}

mount ${loopback_dev} ${image_mount_point}
add_on_exit "umount ${image_mount_point}"

# == Guide to variables in this script (all paths are defined relative to the real root dir, not the chroot)

# work: the base working directory outside the chroot
#      eg: /mnt/stemcells/aws/xen/centos/work/work
# disk_image: path to the stemcell disk image
#      eg: /mnt/stemcells/aws/xen/centos/work/work/aws-xen-centos.raw
# device: path to the loopback devide mapped to the entire disk image
#      eg: /dev/loop0
# loopback_dev: device node mapped to the main partition in disk_image
#      eg: /dev/mapper/loop0p1
# image_mount_point: place where loopback_dev is mounted as a filesystem
#      eg: /mnt/stemcells/aws/xen/centos/work/work/mnt

# Install bootloader
extlinux --install ${image_mount_point}/boot
# Copy mbr.bin, needed for extlinux to work
dd conv=notrunc bs=440 count=1 if=/usr/lib/extlinux/mbr.bin of=${disk_image}


cat >${image_mount_point}/boot/extlinux.conf <<EOF
default linux
timeout 1
label linux
kernel /boot/vmlinuz
append rw init=/sbin/init rootfstype=ext4 root=/dev/vda1 console=ttyS0 console=tty0
EOF


uuid=$(blkid -c /dev/null -sUUID -ovalue ${loopback_dev})

cat > ${image_mount_point}/etc/fstab <<FSTAB
# /etc/fstab Created by BOSH Stemcell Builder
UUID=${uuid} / ext4 defaults 1 1
FSTAB
