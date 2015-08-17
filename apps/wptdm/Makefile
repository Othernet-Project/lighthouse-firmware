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
