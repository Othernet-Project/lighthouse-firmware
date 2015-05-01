TOP_DIR := $(shell pwd)
-include $(TOP_DIR)/../Makefile.in

PKG_VERSION = 6cb7debf14fded1127e075fe547f5a9a8106ba98
PKG_URL = https://github.com/Outernet-Project/librarian/archive/$(PKG_VERSION).tar.gz
PKG_TGZ = librarian-$(PKG_VERSION).tar.gz

STAMP_UNPACKED = librarian/.stamp_unpacked
STAMP_PATCHED = librarian/.stamp_patched
STAMP_BUILT = librarian/.stamp_built

.PHONY: debug release clean install

debug release: $(STAMP_PATCHED)
	(cd librarian && PATH="$(HOST_DIR)/bin:$(HOST_DIR)/sbin:$(HOST_DIR)/usr/bin:$(HOST_DIR)/usr/sbin:$(PATH)" \
	PYTHONPATH="$(TARGET_DIR)/usr/lib/python2.7/sysconfigdata/:$(TARGET_DIR)/usr/lib/python2.7/site-packages/" \
	_python_sysroot=$(HOST_DIR)/usr/arm-buildroot-linux-gnueabi/sysroot \
	_python_prefix=/usr \
	_python_exec_prefix=/usr \
	$(HOST_DIR)/usr/bin/python scripts/cmpmsgs.py librarian/locales )
	(cd librarian && PATH="$(HOST_DIR)/bin:$(HOST_DIR)/sbin:$(HOST_DIR)/usr/bin:$(HOST_DIR)/usr/sbin:$(PATH)" \
	PYTHONPATH="$(TARGET_DIR)/usr/lib/python2.7/sysconfigdata/:$(TARGET_DIR)/usr/lib/python2.7/site-packages/" \
	_python_sysroot=$(HOST_DIR)/usr/arm-buildroot-linux-gnueabi/sysroot \
	_python_prefix=/usr \
	_python_exec_prefix=/usr \
	$(HOST_DIR)/usr/bin/python setup.py build )
	touch $(STAMP_BUILT)

$(STAMP_UNPACKED): $(PKG_TGZ)
	mkdir librarian
	tar --strip-components=1 -C librarian -zxf $(PKG_TGZ)
	touch $(STAMP_UNPACKED)

$(STAMP_PATCHED): $(STAMP_UNPACKED)
	@for PATCH in *.patch; do \
	  patch -p1 -d librarian < $$PATCH ; \
	done
	touch $(STAMP_PATCHED)

$(PKG_TGZ):
	wget $(PKG_URL) -O librarian-$(PKG_VERSION).tar.gz

install: $(STAMP_BUILT)
	( cd librarian && PATH="$(HOST_DIR)/bin:$(HOST_DIR)/sbin:$(HOST_DIR)/usr/bin:$(HOST_DIR)/usr/sbin:$(PATH)" \
	PYTHONPATH="$(TARGET_DIR)/usr/lib/python2.7/sysconfigdata/:$(TARGET_DIR)/usr/lib/python2.7/site-packages/" \
	_python_sysroot=$(HOST_DIR)/usr/arm-buildroot-linux-gnueabi/sysroot \
	_python_prefix=/usr \
	_python_exec_prefix=/usr \
	$(HOST_DIR)/usr/bin/python setup.py install \
	--prefix=$(TARGET_DIR)/usr --executable=/usr/bin/python --single-version-externally-managed --root=/ )
	install -m 0755 S90librarian $(INSTALL_PREFIX)/etc/init.d/

clean:
	-[ -d librarian ] && rm -rf librarian/
