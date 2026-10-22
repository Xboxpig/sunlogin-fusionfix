CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -Werror
CPPFLAGS += $(shell pkg-config --cflags x11)
LDLIBS += -ldl $(shell pkg-config --libs x11)

.PHONY: all clean
all: libsunlogin-fusionfix.so

libsunlogin-fusionfix.so: src/fusionfix.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -fPIC -shared -o $@ $< $(LDLIBS)

clean:
	rm -f libsunlogin-fusionfix.so
