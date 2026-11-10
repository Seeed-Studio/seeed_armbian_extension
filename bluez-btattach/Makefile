# btattach-only build: the minimal link closure of bluez 5.87's
# tools/btattach (determined by the linker; see debian/changelog).
CC ?= cc
CFLAGS ?= -O2
CPPFLAGS += -DHAVE_CONFIG_H -I. -Ilib
LDFLAGS ?=

SRC := tools/btattach.c \
	src/shared/mainloop.c src/shared/mainloop-notify.c \
	src/shared/io-mainloop.c src/shared/timeout-mainloop.c \
	src/shared/util.c src/shared/queue.c src/shared/hci.c

all: btattach

btattach: $(SRC) config.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $(SRC) -o $@

clean:
	rm -f btattach

.PHONY: all clean
