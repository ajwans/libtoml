#ifndef TOML_H
#define TOML_H

#include <ccan/list/list.h>
#include <sys/types.h>
#include <stdio.h>
#include <time.h>

enum toml_type {
	TOML_ROOT,
	TOML_KEYMAP,
	TOML_LIST,
	TOML_INT,
	TOML_FLOAT,
	TOML_STRING,
	TOML_DATE,
};

struct toml_node {
	enum toml_type type;
	char *name;
	union {
		struct list_head map;
		struct list_head list;
		int64_t integer;
		double floating;
		char *string;
		time_t epoch;
	} value;
};

struct toml_map {
	struct list_node map;
	struct toml_node node;
};

struct toml_list {
	struct list_node list;
	struct toml_node node;
};

void toml_init(struct toml_node);
int toml_parse(struct toml_node, int fileno);
void toml_dump(struct toml_node, FILE *);
void toml_free(struct toml_node);

#endif
