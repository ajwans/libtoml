#ifndef TOML_H
#define TOML_H

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

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
	TOML_INLINE_TABLE,
	TOML_MAX
};

struct toml_node;

typedef void (*toml_node_walker)(struct toml_node*, void*);

int toml_init(struct toml_node**);
int toml_parse(struct toml_node*, char*, int);
struct toml_node* toml_get(struct toml_node*, char*);
void toml_dump(struct toml_node*, FILE*);
void toml_tojson(struct toml_node*, FILE*);
void toml_free(struct toml_node*);
void toml_walk(struct toml_node*, toml_node_walker, void*);
void toml_dive(struct toml_node*, toml_node_walker, void*);
enum toml_type toml_type(struct toml_node*);
char* toml_name(struct toml_node*);				/* caller should free return value */
char* toml_value_as_string(struct toml_node*);	/* caller should free return value */

#ifdef __cplusplus
}; // extern "C"
#endif

#endif /* TOML_H */
