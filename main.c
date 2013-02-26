#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>

#include "toml.h"

int main(int argc, char **argv)
{
	int input, ret;
	struct toml_node toml_root;

	if (argc != 2) {
		fprintf(stderr, "Usage: %s <file>\n", argv[0]);
		exit(1);
	}

	input = open(argv[1], O_RDONLY);
	if (input == -1) {
		fprintf(stderr, "open: %s\n", strerror(errno));
		exit(1);
	}

	toml_init(toml_root);

	ret = toml_parse(toml_root, input);

	toml_dump(toml_root, stdout);

	exit(0);
}
