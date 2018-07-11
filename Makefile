#
# Makefile for libphoenix
#
# Copyright 2017 Phoenix Systems
#
# %LICENSE%
#

SIL ?= @
MAKEFLAGS += --no-print-directory --output-sync

#TARGET ?= arm-imx
#TARGET ?= armv7-stm32-tiramisu
TARGET ?= ia32-qemu

VERSION = 0.2
SRCDIR := $(CURDIR)

SUBSYSTEMS := math stdio stdlib string sys ctype time unistd errno signal termios posix err locale regex net
EXTRA_HEADER_DIRS := net netinet arpa



CFLAGS += -DVERSION=\"$(VERSION)\"
CFLAGS += -fdata-sections -ffunction-sections
LDFLAGS += --gc-sections

ARCH = code.a
ARCHS := $(shell for i in $(SUBDIRS); do echo "$$i/$(ARCH)"; done)
OBJS := _startc.o
HEADERS := $(shell find . $(EXTRA_HEADER_DIRS) $(SUBDIRS) -maxdepth 1  -name \*.h)

SYSROOT 		:= $(shell $(CC) $(CFLAGS) -print-sysroot)
MULTILIB_DIR 	:= $(shell $(CC) $(CFLAGS) -print-multi-directory)
LIBC_INSTALL_DIR := $(SYSROOT)/lib/$(MULTILIB_DIR)
LIBC_INSTALL_NAMES := libc.a libm.a crt0.o libg.a
HEADERS_INSTALL_DIR := $(SYSROOT)/usr/include/
ifeq (/,$(SYSROOT))
$(error Sysroot is not supported by Your toolchain. Use cross-toolchain to compile)
endif

export SRCDIR SIL TARGET LIB CC CFLAGS MKDEP MKDEPFLAGS AR ARFLAGS LD LDFLAGS GCCLIB ARCH OBJDUMP STRIP HEADERS_INSTALL_DIR


all: subsystems $(OBJS) $(LIB) tests posixsrv


.c.o:
	@(printf "CC  %-24s  " "$<"; $(CC) -c $(CFLAGS) $<)

	@(file="$@"; \
	datasz=0;\
	textsz=0;\
	for i in `$(OBJDUMP) -t $$file | grep -e " O " | grep -v "\.rodata" | awk '{ print $$4 }'`; do \
		datasz=`echo $$(($$datasz + 0x$$i))`;\
	done; \
	for i in `$(OBJDUMP) -t $$file | grep -e "F" | awk '{ print $$5 }'`; do \
		textsz=`echo $$(($$textsz + 0x$$i))`;\
	done;\
	echo "data=$$datasz\t text=$$textsz")

$(OBJS): $(filter clean,$(MAKECMDGOALS))

subsystems: $(ARCHS)

%/$(ARCH): .FORCE $(filter clean,$(MAKECMDGOALS))
	@+echo "\033[1;32mCOMPILE $(@D)\033[0m";\
	if ! $(MAKE) -C "$(@D)"; then\
		exit 1;\
	fi;\

.FORCE:


$(LIB): $(ARCHS) $(OBJS)
	@echo "\033[1;34mLD $@\033[0m"

	$(AR) $(ARFLAGS) -o $(LIB) $(OBJS) $(shell for i in $(SUBDIRS); do k=`echo $$i | sed 's/\//\\\\\//g'`; $(AR) -t $$i/$(ARCH) | sed "s/^/$$k\//"; done;)

	@(echo "";\
	echo "=> libphoenix for [$(TARGET)] has been created";\
	echo "")


tests: $(LIB)
	@d=`pwd`;\
	echo "\033[1;32mCOMPILE test\033[0m";\
	if ! cd test; then\
		exit 1;\
	fi;\
	if ! $(MAKE); then\
		exit 1;\
	fi;\
	cd $$d;\


posixsrv: $(LIB)
	@d=`pwd`;\
	echo "\033[1;32mCOMPILE posixsrv\033[0m";\
	if ! cd posixsrv; then\
		exit 1;\
	fi;\
	if ! $(MAKE); then\
		exit 1;\
	fi;\
	cd $$d;\


depend:
	@for i in $(SUBDIRS) test; do\
		d=`pwd`;\
		echo "DEPEND $$i";\
		if ! cd $$i; then\
			exit 1;\
		fi;\
		if ! $(MAKE) -s depend; then\
			exit 1;\
		fi;\
		cd $$d;\
	done;

install: $(LIB)
	@echo "Installing into: $(LIBC_INSTALL_DIR)"; \
	mkdir -p "$(LIBC_INSTALL_DIR)" "$(HEADERS_INSTALL_DIR)"; \
	cp -a "$<" "$(LIBC_INSTALL_DIR)"; \
	for lib in $(LIBC_INSTALL_NAMES); do \
		ln -sf "$(LIBC_INSTALL_DIR)/$<" "$(LIBC_INSTALL_DIR)/$$lib"; \
	done; \
	for file in $(HEADERS); do\
		install -m 644 -D $${file} $(HEADERS_INSTALL_DIR)/$${file};\
	done

uninstall:
	rm -rf "$(LIBC_INSTALL_DIR)/$(LIB)"
	@for lib in $(LIBC_INSTALL_NAMES); do \
		rm -rf "$(LIBC_INSTALL_DIR)/$$lib"; \
	done
	@for file in $(HEADERS); do \
		rm -rf "$(HEADERS_INSTALL_DIR)/$${file}"; \
	done

clean:
	@rm -f core *.o $(LIB)
	@for i in $(SUBDIRS) test posixsrv; do\
		d=`pwd`;\
		echo "CLEAN $$i";\
		if ! cd $$i; then\
			exit 1;\
		fi;\
		if ! $(MAKE) clean; then\
			exit 1;\
		fi;\
		cd $$d;\
	done;


.PHONY: clean install uninstall
# DO NOT DELETE
