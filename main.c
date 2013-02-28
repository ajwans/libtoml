#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <libgen.h>

#include "toml.h"

static void
usage(char *progname, int exit_code, char *msg)
{
	char *bname = basename(progname);

	if (msg) {
		fprintf(stderr, "%s\n", msg);
	}
	fprintf(stderr, "Usage: %s -t <toml_file> [-d] [-g <key>]\n", bname);

	exit(exit_code);
}

int main(int argc, char **argv)
{
	int					fd, ret;
	struct toml_node	*toml_root;
	void				*m;
	struct stat			st;
	int					ch, dump = 0;
	char				*file, *get;

	while((ch = getopt(argc, argv, "t:dg:h")) != -1) {
		switch (ch) {
		case 't':
			file = optarg;
			break;

		case 'd':
			dump = 1;
			break;

		case 'g':
			get = optarg;
			break;

		case 'h':
			usage(argv[0], 1, NULL);

		default:
			usage(argv[0], 1, NULL);
			break;
		}
	}

	fd = open(file, O_RDONLY);
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

	ret = munmap(m, st.st_size);
	if (ret) {
		fprintf(stderr, "munmap: %s\n", strerror(errno));
		exit(1);
	}

	if (dump)
		toml_dump(toml_root, stdout);

	if (get) {
		struct toml_node *node = toml_get(toml_root, get);

		if (!node) {
			printf("no node '%s'\n", get);
		} else {
			toml_dump(node, stdout);
		}
	}

	toml_free(toml_root);

	exit(0);
}
