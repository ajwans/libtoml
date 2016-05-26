#ifndef _TOML_PRIVATE_H
#define _TOML_PRIVATE_H

#include <stdint.h>
#include <sys/types.h>
#include <ccan/list/list.h>

#include "toml.h"

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
		struct {
			time_t	epoch;
			int		sec_frac;
			bool	offset_sign_negative;
			uint8_t	offset;
			bool	offset_is_zulu;
		} rfc3339_time;
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

const char* toml_type_to_str(enum toml_type);
int SawTableArray(struct toml_node*, char*, struct toml_node**, char**);
int SawTable(struct toml_node*, char*, struct toml_node**, char**);

#endif /* _TOML_PRIVATE_H */
