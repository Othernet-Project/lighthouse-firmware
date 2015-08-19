TOP_DIR := $(shell pwd)
-include $(TOP_DIR)/../Makefile.in

TARGET = wptdm

.PHONY: debug release clean install

default: debug

debug:
	true 

release:
	true 

clean:
	true 

install: $(TARGET)
	@mkdir -p $(INSTALL_PREFIX)/usr/sbin $(INSTALL_PREFIX)/etc/wptdm/
	install -m 0755 $(TARGET) $(INSTALL_PREFIX)/usr/sbin/
	install -m 0755 S85wptdm $(INSTALL_PREFIX)/etc/init.d/
	install -m 0400 ca.crt $(INSTALL_PREFIX)/etc/wptdm/ca.crt
	install -m 0400 class.pem $(INSTALL_PREFIX)/etc/wptdm/class.pem
