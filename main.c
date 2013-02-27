#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>

#include "toml.h"

int main(int argc, char **argv)
{
	int fd, ret;
	struct toml_node *toml_root;
	void *m;
	struct stat st;

	if (argc != 2) {
		fprintf(stderr, "Usage: %s <file>\n", argv[0]);
		exit(1);
	}

	fd = open(argv[1], O_RDONLY);
	if (fd == -1) {
		fprintf(stderr, "open: %s\n", strerror(errno));
		exit(1);
	}

	ret = fstat(fd, &st);
	if (ret == -1) {
		fprintf(stderr, "stat: %s\n", strerror(errno));
		exit(1);
	}


	m = mmap(NULL, st.st_size, PROT_READ, MAP_FILE|MAP_PRIVATE, fd, 0);
	if (!m) {
		fprintf(stderr, "mmap: %s\n", strerror(errno));
		exit(1);
	}

	ret = toml_init(&toml_root);
	if (ret == -1) {
		fprintf(stderr, "toml_init: %s\n", strerror(errno));
		exit(1);
	}

	ret = toml_parse(toml_root, m, st.st_size);
	if (ret) {
		exit(1);
	}

	toml_dump(toml_root, stdout);

	exit(0);
}
