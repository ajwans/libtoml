#include "toml_private.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

int SawTableArray(struct toml_node* root, char* tableArrayName, struct toml_node** lastTable, char** err)
{
	char *ancestor;

	struct toml_node *place = root;
	struct toml_table_item *new_table_entry = NULL;

	while ((ancestor = strsep(&tableArrayName, "."))) {
		struct toml_table_item *item = NULL;
		struct toml_list_item* new_entry = NULL;
		int found = 0;

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

		fprintf(stderr, "making %s\n", ancestor);
		/*
		 * Create a table array node and insert it into the heirarchy
		 */
		new_entry = malloc(sizeof(*new_entry));
		if (!item) {
			asprintf(err, "malloc error: %s", strerror(errno));
			return -1;
		}
		new_entry->node.name = strdup(ancestor);
		new_entry->node.type = TOML_TABLE_ARRAY;
		list_head_init(&new_entry->node.value.list);
		list_add_tail(&place->value.list, &new_entry->list);

		place = &new_entry->node;
	}

	if (place->type != TOML_TABLE_ARRAY) {
		asprintf(err, "Attempt to overwrite table %s", tableArrayName);
		return -2;
	}

	/*
	 * Create a table which becomes the last element in the list
	 * of maps (table array is a list of maps)
	 */
	new_table_entry = malloc(sizeof(*new_table_entry));
	if (!new_table_entry) {
		asprintf(err, "malloc error: %s", strerror(errno));
		return -1;
	}

	fprintf(stderr, "creating table in ta %s\n", place->name);
	new_table_entry->node.type = TOML_TABLE;
	new_table_entry->node.name = NULL;
	list_head_init(&new_table_entry->node.value.map);
	list_add_tail(&place->value.list, &new_table_entry->map);

	*lastTable = &new_table_entry->node;
	return 0;
}
