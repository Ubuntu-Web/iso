#!/bin/bash

dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts
export HOME=/root
export LC_ALL=C
KERNEL=$(ls -Art /lib/modules | tail -n 1)
mv "/boot/initrd.fromiso" "/boot/initrd.img-$KERNEL"
mv "/boot/vmlinuz.fromiso" "/boot/vmlinuz-$KERNEL"
cd /build/
cd script-ubuntu-web && bash apply
update-initramfs -k all -u
apt clean
rm -rf /tmp/* ~/.bash_history
rm -f /etc/machine-id /var/lib/dbus/machine-id
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
umount /proc || umount -lf /proc
umount /sys
umount /dev/pts
