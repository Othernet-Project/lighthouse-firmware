SUBDIRS := $(shell for D in *; do [ -d $$D ] && echo $$D; done)
JOBS := $(shell grep processor /proc/cpuinfo | wc -l)

.PHONY: $(SUBDIRS) clean debug release install

first: debug

clean debug release install: $(SUBDIRS)

$(SUBDIRS):
	make -C $@ -j$(JOBS) $(MAKECMDGOALS)
