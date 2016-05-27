#include "toml_private.h"

#include <ccan/list/list.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

const char *
toml_type_to_str(enum toml_type type)
{
#define CASE_ENUM_TO_STR(x) case(x): return #x
	switch (type) {
	CASE_ENUM_TO_STR(TOML_ROOT);
	CASE_ENUM_TO_STR(TOML_TABLE);
	CASE_ENUM_TO_STR(TOML_LIST);
	CASE_ENUM_TO_STR(TOML_INT);
	CASE_ENUM_TO_STR(TOML_FLOAT);
	CASE_ENUM_TO_STR(TOML_STRING);
	CASE_ENUM_TO_STR(TOML_DATE);
	CASE_ENUM_TO_STR(TOML_BOOLEAN);
	CASE_ENUM_TO_STR(TOML_TABLE_ARRAY);
	CASE_ENUM_TO_STR(TOML_INLINE_TABLE);
	default:
		return "unknown toml type";
	}
#undef CASE_ENUM_TO_STR
}

static struct toml_node*
InsertAnonymousTable(struct toml_node* place)
{
	struct toml_table_item* new_table;
	new_table = malloc(sizeof(*new_table));
	new_table->node.type = TOML_TABLE;
	new_table->node.name = NULL;
	list_head_init(&new_table->node.value.map);
	list_add_tail(&place->value.list, &new_table->map);
	return &new_table->node;
}

static struct toml_node*
InsertTableArray(char* name, struct toml_node* place)
{
	struct toml_table_item* item;

	item = malloc(sizeof(*item));
	item->node.type = TOML_TABLE_ARRAY;
	item->node.name = strdup(name);
	list_head_init(&item->node.value.list);
	list_add_tail(&place->value.map, &item->map);

	return InsertAnonymousTable(&item->node);
}

int
SawTableArray(struct toml_node* root, char* tableArrayName, struct toml_node** lastTable, char** err)
{
	char*					ancestor;
	bool					found = false;
	struct toml_table_item*	item;
	struct toml_node*		place;

	if (root->type != TOML_ROOT)
		return 1;

	/*
	 * A table array is a list of anonymous tables.  Every time we see [[<table>]]
	 * we should first instantiate <table> if it does not already exist.  Once we
	 * have <table> we must add a new anonymous TOML_TABLE and set it to be the
	 * current table.
	 */
	place = root;

	while ((ancestor = strsep(&tableArrayName, "."))) {
		found = false;

		list_for_each(&place->value.map, item, map) {
			if (!item->node.name)
				continue;

			if (!strcmp(item->node.name, ancestor))
			{
				struct toml_list_item* last;
				last = list_tail(&item->node.value.list, struct toml_list_item, list);
				place = &last->node;
				found = true;
				break;
			}
		}

		if (found)
			continue;

		/* this is the instantiation of <table> or one of its sub-parts */
		place = InsertTableArray(ancestor, place);
		*lastTable = place;
	}

	/* This is the creation of an anoymous table once we reach the base of tableArrayName */
	if (found)
		*lastTable = InsertAnonymousTable(&item->node);

	return 0;
}

int
SawTable(struct toml_node* place, char* name, struct toml_node** lastTable, char** err)
{
	char *ancestor, *tofree = NULL, *tablename;
	int item_added = 0;

	tofree = tablename = strdup(name);
	if (!tablename)
		return ENOMEM;

	while ((ancestor = strsep(&tablename, "."))) {
		struct toml_table_item *item = NULL;
		int found = 0;

		if (strcmp(ancestor, "") == 0) {
			asprintf(err, "empty implicit table");
			return 1;
		}

		list_for_each(&place->value.map, item, map) {
			if (!item->node.name)
				continue;

			if (strcmp(item->node.name, ancestor) == 0) {
				place = &item->node;
				found = 1;
				break;
			}
		}

		if (found)
			continue;

		/* this is the auto-vivification */
		item = malloc(sizeof(*item));
		if (!item)
			return ENOMEM;

		item->node.name = strdup(ancestor);
		item->node.type = TOML_TABLE;
		list_head_init(&item->node.value.map);
		list_add_tail(&place->value.map, &item->map);

		place = &item->node;
		item_added = 1;
	}

	if (!item_added) {
		asprintf(err, "Duplicate item %s", name);
		return 2;
	}

	if (place->type != TOML_TABLE) {
		asprintf(err, "Attempt to overwrite table %s", name);
		return 3;
	}

	free(tofree);

	*lastTable = place;
	return 0;
}
