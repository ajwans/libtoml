#include "toml.h"

#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>

void toml_init(struct toml_node toml_root)
{
	toml_root.type = TOML_ROOT;
	toml_root.name = NULL;
	list_head_init(&toml_root.value.map);
}

int toml_parse(struct toml_node toml_root, int fileno)
{
	assert(toml_root.type == TOML_ROOT);
	read(fileno, NULL, 0);
	return 0;
}

static void _toml_dump(struct toml_node *toml_node, FILE *output, int indent)
{
	for (int i = 0; i < indent; i++)
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

	default:
		assert(-1 == toml_node->type);
	}
}

void toml_dump(struct toml_node toml_root, FILE *output)
{
	assert(toml_root.type == TOML_ROOT);
	_toml_dump(&toml_root, output, 0);
}

static void _toml_free(struct toml_node *node)
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
		break;
	}
}

void toml_free(struct toml_node toml_root)
{
	assert(toml_root.type == TOML_ROOT);
	_toml_free(&toml_root);
}
