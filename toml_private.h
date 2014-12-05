#ifndef _TOML_PRIVATE_H
#define _TOML_PRIVATE_H

#include <stdint.h>
#include <sys/types.h>
#include <ccan/list/list.h>

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

#endif /* _TOML_PRIVATE_H */
