SRCS := toml.c
OBJS := $(SRCS:.c=.o)

CFLAGS := -Wall -Wextra -Werror -I.

all: libtoml

clean:
	rm -f $(OBJS)
	rm -f libtoml.so

libtoml: $(OBJS)
