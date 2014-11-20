#ifndef TOML_H
#define TOML_H

#include <ccan/list/list.h>
#include <sys/types.h>
#include <stdio.h>
#include <time.h>

enum toml_type {
	TOML_ROOT = 1,
	TOML_TABLE,
	TOML_LIST,
	TOML_INT,
	TOML_FLOAT,
	TOML_STRING,
	TOML_DATE,
	TOML_BOOLEAN,
	TOML_TABLE_ARRAY,
};

struct toml_node {
	enum toml_type type;
	char *name;
	union {
		struct list_head map;
		struct list_head list;
		int64_t integer;
		struct {
			double	value;
			int		precision;
		} floating;
		char *string;
		time_t epoch;
	} value;
};

struct toml_table_item {
	struct list_node map;
	struct toml_node node;
};

struct toml_list_item {
	struct list_node list;
	struct toml_node node;
};

typedef void (*toml_node_walker)(struct toml_node *, void *);

int toml_init(struct toml_node **);
int toml_parse(struct toml_node *, char *, int);
struct toml_node *toml_get(struct toml_node *, char *);
void toml_dump(struct toml_node *, FILE *);
void toml_tojson(struct toml_node *, FILE *);
void toml_free(struct toml_node *);
void toml_walk(struct toml_node *, toml_node_walker, void *);
void toml_dive(struct toml_node *, toml_node_walker, void *);

#endif
