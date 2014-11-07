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
	fprintf(stderr, "Usage: %s -t <toml_file> [-d] [-j] [-g <key>]\n", bname);
	fprintf(stderr, "\t-t <toml_file>	file to parse\n");
	fprintf(stderr, "\t-d				dump file contents\n");
	fprintf(stderr, "\t-j				dump as JSON (default is TOML)\n");
	fprintf(stderr, "\t-g <key>			dump file contents starting from <key>\n");

	exit(exit_code);
}

int main(int argc, char **argv)
{
	int					fd, ret;
	struct toml_node	*toml_root;
	void				*m;
	struct stat			st;
	int					ch, dump = 0, json = 0;
	char				*file, *get = NULL;
	int					exit_code = EXIT_SUCCESS;

	while((ch = getopt(argc, argv, "t:dg:hj")) != -1) {
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
			break;

		case 'j':
			json = 1;
			break;

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
		exit(EXIT_FAILURE);
	}

	m = mmap(NULL, st.st_size, PROT_READ, MAP_FILE|MAP_PRIVATE, fd, 0);
	if (!m) {
		fprintf(stderr, "mmap: %s\n", strerror(errno));
		exit(EXIT_FAILURE);
	}

	ret = toml_init(&toml_root);
	if (ret == -1) {
		fprintf(stderr, "toml_init: %s\n", strerror(errno));
		exit(EXIT_FAILURE);
	}

	ret = toml_parse(toml_root, m, st.st_size);
	if (ret) {
		exit_code = EXIT_FAILURE;
		goto bail;
	}

	ret = munmap(m, st.st_size);
	if (ret) {
		fprintf(stderr, "munmap: %s\n", strerror(errno));
		exit_code = EXIT_FAILURE;
		goto bail;
	}

	close(fd);

	if (dump) {
		if (json)
			toml_tojson(toml_root, stdout);
		else
			toml_dump(toml_root, stdout);
	} else if (get) {
		struct toml_node *node = toml_get(toml_root, get);

		if (!node) {
			fprintf(stderr, "no node '%s'\n", get);
			exit_code = EXIT_FAILURE;
			goto bail;
		}

		if (json)
			toml_tojson(node, stdout);
		else
			toml_dump(node, stdout);
	}

bail:
	toml_free(toml_root);

	exit(exit_code);
}
