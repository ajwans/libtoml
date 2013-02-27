#include "toml.h"

#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#include <string.h>

int
toml_init(struct toml_node **toml_root)
{
	*toml_root = malloc(sizeof(**toml_root));
	if (!*toml_root) {
		return -1;
	}

	(*toml_root)->type = TOML_ROOT;
	(*toml_root)->name = NULL;
	list_head_init(&(*toml_root)->value.map);
	return 0;
}

static void
_toml_dump(struct toml_node *toml_node, FILE *output, int indent)
{
	int i;

	for (i = 0; i < indent; i++)
		fprintf(output, "\t");

	switch (toml_node->type) {
	case TOML_ROOT: {
		struct toml_map *toml_map = NULL;

		list_for_each(&toml_node->value.map, toml_map, map) {
			_toml_dump(&toml_map->node, output, indent);
		}
		break;
	}

	case TOML_KEYMAP: {
		struct toml_map *toml_map = NULL;

		fprintf(output, "[%s]\n", toml_node->name);
		list_for_each(&toml_node->value.map, toml_map, map) {
			_toml_dump(&toml_map->node, output, indent+1);
		}
		fprintf(output, " ]\n");
		break;
	}

	case TOML_LIST: {
		struct toml_list *toml_list = NULL;

		fprintf(output, "%s = [ ", toml_node->name);
		list_for_each(&toml_node->value.list, toml_list, list) {
			_toml_dump(&toml_list->node, output, 0);
			fprintf(output, ", ");
		}
		fprintf(output, " ]\n");

		break;
	}

	case TOML_INT:
		if (toml_node->name)
			fprintf(output, "%s = ", toml_node->name);
		fprintf(output, "%"PRId64"\n", toml_node->value.integer);
		break;

	case TOML_FLOAT:
		if (toml_node->name)
			fprintf(output, "%s = ", toml_node->name);
		fprintf(output, " %f\n", toml_node->value.floating);
		break;

	case TOML_STRING:
		if (toml_node->name)
			fprintf(output, "%s = ", toml_node->name);
		fprintf(output, "\"%s\"\n", toml_node->value.string);
		break;

	case TOML_DATE: {
		struct tm tm;

		if (!gmtime_r(&toml_node->value.epoch, &tm)) {
			char buf[1024];
			strerror_r(errno, buf, sizeof(buf));
			fprintf(stderr, "gmtime failed: %s", buf);
		}

		if (toml_node->name)
			fprintf(output, "%s = ", toml_node->name);

		fprintf(output, "%d-%02d-%02dT%02d:%02d:%0dZ", 1900 + tm.tm_year,
				tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec);
		break;
	}

	default:
		assert(toml_node->type);
	}
}

void
toml_dump(struct toml_node *toml_root, FILE *output)
{
	assert(toml_root->type == TOML_ROOT);
	_toml_dump(toml_root, output, 0);
}

static void
_toml_free(struct toml_node *node)
{
	if (node->name)
		free(node->name);

	switch (node->type) {
	case TOML_ROOT:
	case TOML_KEYMAP: {
		struct toml_map *toml_map = NULL;

		list_for_each(&node->value.map, toml_map, map)
			_toml_free(&toml_map->node);
		break;
	}

	case TOML_LIST: {
		struct toml_list *toml_list = NULL;

		list_for_each(&node->value.list, toml_list, list)
			_toml_free(&toml_list->node);
		break;
	}

	case TOML_STRING:
		free(node->value.string);
		break;

	case TOML_INT:
	case TOML_FLOAT:
	case TOML_DATE:
		break;
	}

	free(node);
}

void
toml_free(struct toml_node *toml_root)
{
	assert(toml_root->type == TOML_ROOT);
	_toml_free(toml_root);
}
