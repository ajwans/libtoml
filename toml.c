#include "toml.h"

#include <stdio.h>
#include <stdlib.h>

#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>

void toml_init(struct toml_node toml_root)
{
	toml_root.type = TOML_ROOT;
	list_head_init(&toml_root.value.map);
}

int toml_parse(struct toml_node toml_root, int fileno)
{
	assert(toml_root.type == TOML_ROOT);
	read(fileno, NULL, 0);
}

static void _toml_dump(struct toml_node *toml_node, FILE *output, int indent)
{
	for (int i = 0; i < indent; i++)
		fprintf(output, "\t");

	switch (toml_node.type) {
	case TOML_ROOT:
		assert(0);
	case TOML_KEYMAP: {
		struct toml_map *toml_map;

		fprintf(output, "[%s]\n", toml_node.name);
		list_for_each(&toml_node.value.map, toml_list, list) {
			toml_dump(toml_map->node, output, indent+1);
		}
		fprintf(output, " ]\n");
		break;
	}

	case TOML_LIST: {
		struct toml_list *toml_list;

		fprintf(output, "%s = [ ", toml_node.name);
		list_for_each(&toml_node.value.list, toml_list, list) {
			toml_dump(toml_list->node, output, 0);
			fprintf(output, ", ");
		}
		fprintf(output, " ]\n");

		break;
	}

	case TOML_INT:
		fprintf(output, "%s = %"PRId64"\n", toml_node.name,
													toml_node.value.integer);
		break;

	case TOML_FLOAT:
		fprintf(output, "%s = %f\n", toml_node.name, toml_node.value.floating);
		break;

	case TOML_STRING:
		fprintf(output, "%s = \"%s\"\n", toml_node.name,
													toml_node.value.string);
		break;

	default:
		assert(-1 == toml_node.type);
	}
}

void toml_dump(struct toml_node toml_root, FILE *output)
{
	int indent = 0;
	assert(toml_root.type == TOML_ROOT);
	_toml_dump(toml_root, output, 0);
}

void toml_free(struct toml_node toml_root)
{
	list_for_each
}
