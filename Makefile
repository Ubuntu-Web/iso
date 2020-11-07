.PHONY: enter iso test

SHELL=/bin/bash

all: iso

enter: .edit.timestamp
	cp /etc/resolv.conf edit/etc/
	- cp edit/etc/hosts .hosts.backup || true
	cp /etc/hosts edit/etc/
	cp -r build edit/
	cp extract-cd/casper/initrd edit/boot/initrd.fromiso
	cp extract-cd/casper/vmlinuz edit/boot/vmlinuz.fromiso
	mount -o bind /run/ edit/run
	mount -o bind /dev/ edit/dev
	chroot edit /build/build.sh
	umount edit/dev
	umount edit/run
	rm edit/etc/hosts
	- mv .hosts.backup edit/etc/hosts || true
	cp edit/boot/vmlinuz extract-cd/casper/vmlinuz
	cp edit/boot/initrd.img extract-cd/casper/initrd
	rm -rf edit/build/
	rm -rf edit/root/.bash_history
	rm -rf edit/root/.cache
	touch .enter.timestamp

.edit.timestamp:
	mkdir -p mnt
	mount -o loop ubuntu.iso mnt
	unsquashfs mnt/casper/filesystem.squashfs
	mv squashfs-root edit
	cp -r mnt/ extract-cd/ && rm -f extract-cd/filesystem.squashfs extract-cd/filesystem.squashfs.gpg
	umount mnt
	rmdir mnt
	touch .edit.timestamp

.enter.timestamp: enter
	touch .enter.timestamp

extract-cd/casper/filesystem.manifest: .edit.timestamp .enter.timestamp
	chmod +w extract-cd/casper/filesystem.manifest
	chroot edit dpkg-query -W --showformat='$${Package} $${Version}\n' > extract-cd/casper/filesystem.manifest

extract-cd/casper/filesystem.squashfs: extract-cd/casper/filesystem.manifest
	- rm extract-cd/casper/filesystem.squashfs
	mksquashfs edit extract-cd/casper/filesystem.squashfs -b 1048576 -comp xz -always-use-fragments

extract-cd/casper/filesystem.squashfs.gpg: extract-cd/casper/filesystem.squashfs
	@rm -f extract-cd/casper/filesystem.squashfs.gpg

extract-cd/casper/filesystem.size: extract-cd/casper/filesystem.squashfs extract-cd/casper/filesystem.squashfs.gpg
	printf $$(sudo du -sx --block-size=1 edit | cut -f1) > extract-cd/casper/filesystem.size

extract-cd/README.diskdefines:
	source build.conf && echo '#define DISKNAME  '"$$DISKNAME" > extract-cd/README.diskdefines
	echo '#define TYPE  binary' >> extract-cd/README.diskdefines
	echo '#define TYPEbinary  1' >> extract-cd/README.diskdefines
	echo '#define ARCH  amd64' >> extract-cd/README.diskdefines
	echo '#define ARCHamd64  1' >> extract-cd/README.diskdefines
	echo '#define DISKNUM  1' >> extract-cd/README.diskdefines
	echo '#define DISKNUM1  1' >> extract-cd/README.diskdefines
	echo '#define TOTALNUM  0' >> extract-cd/README.diskdefines
	echo '#define TOTALNUM0  1' >> extract-cd/README.diskdefines

extract-cd/.disk/info: .edit.timestamp .enter.timestamp
	source build.conf && echo "$$DISKNAME" > extract-cd/.disk/info

extract-cd/boot/grub.cfg: .edit.timestamp .enter.timestamp
	cp grub.cfg extract-cd/boot/grub/grub.cfg

extract-cd/md5sum.txt: extract-cd/casper/filesystem.squashfs extract-cd/casper/filesystem.size
	cd extract-cd; rm md5sum.txt; find -type f -print0 | sudo xargs -0 md5sum | /usr/bin/env grep -v 'md5sum.txt' | /usr/bin/env grep -v 'boot.catalog' | /usr/bin/env grep -v 'eltorito.img' > md5sum.txt

build.iso: extract-cd/.disk/info extract-cd/boot/grub.cfg extract-cd/README.diskdefines extract-cd/md5sum.txt
	cp grub.cfg extract-cd/boot/grub/grub.cfg
	source build.conf && rm -f "$$OUT_ISO" && grub-mkrescue -o "$$OUT_ISO" extract-cd/
	source build.conf && rm -f "$$OUT_ISO.md5sum" && md5sum "$$OUT_ISO" > "$$OUT_ISO.md5sum"

iso: build.iso

clean:
	@rm -rf edit extract-cd mnt squashfs-root .edit.timestamp .enter.timestamp

clean-iso: clean
	source build.conf && rm -f "$$OUT_ISO" "$$OUT_ISO.md5sum"
