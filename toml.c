#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#include <string.h>
#include <ccan/list/list.h>

#include "toml.h"

int
toml_init(struct toml_node **toml_root)
{
	struct toml_node *toml_node;

	toml_node = malloc(sizeof(*toml_node));
	if (!toml_node) {
		return -1;
	}

	toml_node->type = TOML_ROOT;
	toml_node->name = NULL;
	list_head_init(&toml_node->value.map);

	*toml_root = toml_node;
	return 0;
}

struct toml_node *
toml_get(struct toml_node *toml_root, char *key)
{
	char *ancestor, *tofree, *name;
	struct toml_node *node = toml_root;

	tofree = name = strdup(key);

	while ((ancestor = strsep(&name, "."))) {
		struct toml_keygroup_item *item;
		int found = 0;

		list_for_each(&node->value.map, item, map) {
			if (strcmp(item->node.name, ancestor) == 0) {
				node = &item->node;
				found = 1;
				break;
			}
		}

		if (!found) {
			node = NULL;
			break;
		}
	}

	free(tofree);

	return node;
}

static void
_toml_dump(struct toml_node *toml_node, FILE *output, char *bname, int indent,
																	int newline)
{
	int i;

	for (i = 0; i < indent - 1; i++)
		fprintf(output, "\t");

	switch (toml_node->type) {
	case TOML_ROOT: {
		struct toml_keygroup_item *item = NULL;

		list_for_each(&toml_node->value.map, item, map) {
			_toml_dump(&item->node, output, toml_node->name, indent, 1);
		}
		break;
	}

	case TOML_KEYGROUP: {
		struct toml_keygroup_item *item = NULL;
		char name[100];

		sprintf(name, "%s%s%s", bname ? bname : "", bname ? "." : "",
															toml_node->name);

		fprintf(output, "%s[%s]\n", indent ? "\t": "", name);
		list_for_each(&toml_node->value.map, item, map) {
			_toml_dump(&item->node, output, name, indent+1, 1);
		}
		fprintf(output, "\n");
		break;
	}

	case TOML_LIST: {
		struct toml_list_item *item = NULL;

		if (toml_node->name)
			fprintf(output, "%s = ", toml_node->name);
		fprintf(output, "[ ");
		list_for_each(&toml_node->value.list, item, list) {
			_toml_dump(&item->node, output, toml_node->name, 0, 0);
			fprintf(output, ", ");
		}
		fprintf(output, " ]%s", newline ? "\n" : "");

		break;
	}

	case TOML_INT:
		if (toml_node->name)
			fprintf(output, "%s = ", toml_node->name);
		fprintf(output, "%"PRId64"%s", toml_node->value.integer,
														newline ? "\n" : "");
		break;

	case TOML_FLOAT:
		if (toml_node->name)
			fprintf(output, "%s = ", toml_node->name);
		fprintf(output, " %f%s", toml_node->value.floating,
														newline ? "\n" : "");
		break;

	case TOML_STRING:
		if (toml_node->name)
			fprintf(output, "%s = ", toml_node->name);
		fprintf(output, "\"%s\"%s", toml_node->value.string,
														newline ? "\n" : "");
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

		fprintf(output, "%d-%02d-%02dT%02d:%02d:%02dZ%s", 1900 + tm.tm_year,
				tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec,
				newline ? "\n" : "");
		break;
	}

	default:
		fprintf(stderr, "unknown toml type %d\n", toml_node->type);
		/* assert(toml_node->type); */
	}
}

void
toml_dump(struct toml_node *toml_root, FILE *output)
{
	_toml_dump(toml_root, output, NULL, 0, 1);
}

static void
_toml_free(struct toml_node *node)
{
	if (node->name)
		free(node->name);

	switch (node->type) {
	case TOML_ROOT:
	case TOML_KEYGROUP: {
		struct toml_keygroup_item *item = NULL, *next = NULL;

		list_for_each_safe(&node->value.map, item, next, map) {
			list_del(&item->map);
			_toml_free(&item->node);
			free(item);
		}
		break;
	}

	case TOML_LIST: {
		struct toml_list_item *item = NULL, *next = NULL;

		list_for_each_safe(&node->value.list, item, next, list) {
			list_del(&item->list);
			_toml_free(&item->node);
			free(item);
		}
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
}

void
toml_free(struct toml_node *toml_root)
{
	assert(toml_root->type == TOML_ROOT);
	_toml_free(toml_root);
	free(toml_root);
}
