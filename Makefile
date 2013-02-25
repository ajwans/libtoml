SRCS := toml.c
OBJS := $(SRCS:.c=.o)

CFLAGS := -Wall -Wextra -Werror -ggdb -fPIC -Wstrict-prototypes -I. \
		  -Wmissing-prototypes -D_FORTIFY_SOURCE=2 -Wshadow -D_GNU_SOURCE

LIBNAME := toml

ARCH := $(shell uname -m)
ifeq ($(ARCH),x86_64)
	CFLAGS += -m64
endif

PLATFORM := $(shell uname -s)
ifeq ($(PLATFORM),Darwin)
	LIBEXT=dylib
	LDFLAGS := -dynamic -dylib -lSystem
else
	LIBEXT=so
	LDFLAGS := -Bdynamic -shared
endif

all: shared

shared: lib$(LIBNAME).$(LIBEXT)

lib$(LIBNAME).$(LIBEXT): $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

clean:
	rm -f $(OBJS)
	rm -f lib$(LIBNAME).$(LIBEXT)
