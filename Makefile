SRCS := toml.c toml_parse.c
OBJS := $(SRCS:.c=.o)

CC := gcc
CFLAGS := -Wall -Wextra -Werror -ggdb -fPIC -Wstrict-prototypes -I.			\
		  -Wmissing-prototypes -D_FORTIFY_SOURCE=2 -Wshadow -D_GNU_SOURCE	\
		  -I/opt/local/include

LIBNAME := toml

ARCH := $(shell uname -m)
ifeq ($(ARCH),x86_64)
	CFLAGS += -m64
endif

PLATFORM := $(shell uname -s)
ifeq ($(PLATFORM),Darwin)
	LIBEXT=dylib
	LDFLAGS := -dynamic -dylib -lSystem -arch $(ARCH)
else
	LIBEXT=so
	LDFLAGS := -Bdynamic -shared
endif

all: shared main

shared: lib$(LIBNAME).$(LIBEXT)

lib$(LIBNAME).$(LIBEXT): $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

main: main.o shared
	$(CC) $(CFLAGS) -o $@ $< -L$(PWD) -l$(LIBNAME)

test: test.o shared
	$(CC) $(CFLAGS) -o $@ $< -L$(PWD) -l$(LIBNAME) -L/opt/local/lib -lcunit -lncurses

%.c: %.rl
	ragel -G2 $<

%.dot: %.rl
	ragel -G2 -V $< > $@

%.png: %.dot
	dot -Tpng -o$@ $<

clean:
	rm -f $(OBJS)
	rm -f lib$(LIBNAME).$(LIBEXT)
	rm -f toml_parse.dot
	rm -f toml_parse.png

.PRECIOUS: toml_parse.c
