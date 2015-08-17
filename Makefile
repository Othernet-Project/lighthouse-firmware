include buildroot/.config

CROSS_COMPILE := $(strip $(subst ",,$(BR2_TOOLCHAIN_EXTERNAL_PATH)/bin/$(BR2_TOOLCHAIN_EXTERNAL_PREFIX)-))
IMAGES_DIR := buildroot/output/images

VERSION := $(shell cat version 2> /dev/null)
PACKAGE := outernet-rx-$(VERSION).pkg
RESET_TOKEN := $(shell cat reset_token 2> /dev/null)

KERNEL = $(IMAGES_DIR)/kernel.img
ROOTFS = $(IMAGES_DIR)/rootfs.ubifs

.PHONY: build mfg clean buildroot-menuconfig linux-menuconfig

default: $(PACKAGE)

build: .stamp_buildroot

$(PACKAGE): version $(KERNEL) $(ROOTFS) scripts/installer.sh
	./buildroot/output/host/usr/bin/mkpkg -o $@ \
		version scripts/installer.sh:run.sh $(KERNEL) $(ROOTFS)

$(PACKAGE).signed: version package.pem $(KERNEL) $(ROOTFS) scripts/installer.sh
	read -r -p "Package key password: " PASSWORD && \
	./buildroot/output/host/usr/bin/mkpkg -k package.pem -p "$$PASSWORD" -o $@ \
		version scripts/installer.sh:run.sh $(KERNEL) $(ROOTFS)

$(ROOTFS): .stamp_buildroot .stamp_apps .stamp_tools
	make -C buildroot/

.stamp_buildroot: buildroot/.config
	@make -C buildroot/ target-finalize
	@echo "wt200" > buildroot/output/target/etc/platform
	@echo $(VERSION) > buildroot/output/target/etc/version
	@echo $(RESET_TOKEN) > buildroot/output/target/etc/emergency.token
	@touch .stamp_buildroot

buildroot/.config:
	@make -C buildroot/ outernetrx_defconfig

buildroot-menuconfig: buildroot/.config
	@make -C buildroot menuconfig

buildroot-savedefconfig: buildroot/.config
	@cp buildroot/.config buildroot/configs/outernetrx_defconfig

.stamp_apps: .stamp_buildroot
	@make -C apps/ release
	@make -C apps/ install
	@touch .stamp_apps

.stamp_tools: .stamp_buildroot
	@make -C tools/ release
	@make -C tools/ install
	@touch .stamp_tools

KERNEL_UIMAGE = linux/arch/arm/boot/uImage
KERNEL_DTB = linux/arch/arm/boot/dts/amlogic/wetek_play.dtb
KERNEL_INITRAMFS = linux/initramfs.cpio.gz

$(KERNEL): $(KERNEL_UIMAGE) $(KERNEL_DTB) $(KERNEL_INITRAMFS)
	mkdir -p $(IMAGES_DIR)
	./linux/mkbootimg --kernel $(KERNEL_UIMAGE) --ramdisk $(KERNEL_INITRAMFS) --second $(KERNEL_DTB) --output $(KERNEL)

$(KERNEL_INITRAMFS): .stamp_buildroot scripts/init scripts/init.ramfs
	mkdir -p $(IMAGES_DIR)
	./linux/usr/gen_init_cpio scripts/init.ramfs | gzip > $@

$(KERNEL_DTB): linux/.config
	ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) make -C linux/ wetek_play.dtd
	ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) make -C linux/ wetek_play.dtb

$(KERNEL_UIMAGE): linux/.config
	ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) make -C linux/ -j4 uImage

linux/.config:
	ARCH=arm make -C linux/ outernetrx_defconfig

linux-menuconfig: linux/.config
	ARCH=arm make -C linux/ menuconfig

mfg: $(KERNEL_UIMAGE) $(KERNEL_DTB)
	make -C buildroot/ distclean
	make -C buildroot/ outernetrx_mfg_defconfig
	make -C buildroot/
	./linux/mkbootimg --kernel $(KERNEL_UIMAGE) --ramdisk ./buildroot/output/images/rootfs.cpio.gz \
	  --second $(KERNEL_DTB) --output kernel_mfg.img

clean:
	make -C buildroot/ clean
	make -C linux/ clean
	make -C apps/ clean
	make -C tools/ clean
	-rm .stamp_*
