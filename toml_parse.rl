#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <time.h>

#include "toml.h"
#include <signal.h>
#include <unicode/ustring.h>

struct toml_stack_item {
	struct list_node list;
	enum toml_type list_type;
	struct toml_node *node;
};

static const char *
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
	}
#undef CASE_ENUM_TO_STR
	return "unknown toml type";
}

static size_t
utf32ToUTF8(char* dst, int len, uint32_t utf32)
{
	if (utf32 < 0x80) {
		if (len < 1)
			return 0;

		*dst = (uint8_t)utf32;
		return 1;
	}

	if (utf32 < 0x000800)
	{
		if (len < 2)
			return 0;

		dst[0] = (uint8_t)(0xc0 | (utf32 >> 6));
		dst[1] = (uint8_t)(0x80 | (utf32 & 0x3f));
		return 2;
	}

	if (utf32 < 0x10000)
	{
		if (len < 3)
			return 0;

		dst[0] = (uint8_t)(0xE0 | (utf32 >> 12));
		dst[1] = (uint8_t)(0x80 | ((utf32 & 0x0FC0) >> 6));
		dst[2] = (uint8_t)(0x80 | (utf32 & 0x003F));
		return 3;
	}

	if (len < 4)
		return 0;

	dst[0] = (uint8_t)(0xF0 | (utf32 >> 18));
	dst[1] = (uint8_t)(0x80 | ((utf32 & 0x03F000) >> 12));
	dst[2] = (uint8_t)(0x80 | ((utf32 & 0x000FC0) >> 6));
	dst[3] = (uint8_t)(0x80 | (utf32 & 0x00003F));

	return 4;
}

%%{
	machine toml;

	whitespace = [\t ]*;

	name = (print - (whitespace|']'|'['))+ >{ts = p;};

	action float_add_place {
		floating += (fc - '0') * ((float)1/dec_pos);
		dec_pos *= 10;
	}

	action saw_key {
		name = strndup(ts, namelen);
	}

	action saw_bool {
		struct toml_stack_item *cur_list =
						list_tail(&list_stack, struct toml_stack_item, list);

		if (cur_list) {
			if (cur_list->list_type && cur_list->list_type != TOML_BOOLEAN) {
				asprintf(&parse_error,
						"incompatible types list %s this %s line %d\n",
						toml_type_to_str(cur_list->list_type),
						toml_type_to_str(TOML_BOOLEAN), curline);
				fbreak;
			}
			cur_list->list_type = TOML_BOOLEAN;

			struct toml_list_item *item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}

			item->node.type = TOML_BOOLEAN;
			item->node.value.integer = number;
			item->node.name = NULL;

			list_add_tail(&cur_list->node->value.list, &item->list);

			fnext list;
		} else {
			struct toml_table_item *item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}

			item->node.name = name;
			item->node.type = TOML_BOOLEAN;
			item->node.value.integer = number;

			list_add_tail(&cur_table->value.map, &item->map);
		}
	}

	action saw_int {
		number *= sign;

		struct toml_stack_item *cur_list =
						list_tail(&list_stack, struct toml_stack_item, list);

		if (cur_list) {
			if (cur_list->list_type && cur_list->list_type != TOML_INT) {
				asprintf(&parse_error,
						"incompatible types list %s this %s line %d\n",
						toml_type_to_str(cur_list->list_type),
						toml_type_to_str(TOML_INT), curline);
				fbreak;
			}
			cur_list->list_type = TOML_INT;

			struct toml_list_item *item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}

			item->node.type = TOML_INT;
			item->node.value.integer = number;
			item->node.name = NULL;

			list_add_tail(&cur_list->node->value.list, &item->list);

			fnext list;
		} else {
			struct toml_table_item *item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}

			item->node.name = name;
			item->node.type = TOML_INT;
			item->node.value.integer = number;

			list_add_tail(&cur_table->value.map, &item->map);
		}

		fhold;
	}

	action saw_float {
		floating *= sign;

		struct toml_stack_item *cur_list =
						list_tail(&list_stack, struct toml_stack_item, list);

		if (cur_list) {
			if (cur_list->list_type && cur_list->list_type != TOML_FLOAT) {
				asprintf(&parse_error,
						"incompatible types list %s this %s line %d\n",
						toml_type_to_str(cur_list->list_type),
						toml_type_to_str(TOML_FLOAT), curline);
				fbreak;
			}
			cur_list->list_type = TOML_FLOAT;

			struct toml_list_item *item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}

			item->node.type = TOML_FLOAT;
			item->node.value.floating = floating;
			item->node.name = NULL;

			list_add_tail(&cur_list->node->value.list, &item->list);

			fnext list;
		} else {
			struct toml_table_item *item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}

			list_add_tail(&cur_table->value.map, &item->map);
			item->node.name = name;
			item->node.type = TOML_FLOAT;
			item->node.value.floating = floating;
		}

		fhold;
	}

	action saw_string {
		int len = strp - string + 1;
		*strp = 0;

		struct toml_stack_item *cur_list =
						list_tail(&list_stack, struct toml_stack_item, list);

		if (cur_list) {
			if (cur_list->list_type && cur_list->list_type != TOML_STRING) {
				asprintf(&parse_error,
						"incompatible types list %s this %s line %d\n",
						toml_type_to_str(cur_list->list_type),
						toml_type_to_str(TOML_STRING), curline);
				fbreak;
			}
			cur_list->list_type = TOML_STRING;

			struct toml_list_item *item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}

			item->node.type = TOML_STRING;
			item->node.value.string = malloc(len);
			if (!item->node.value.string) {
				malloc_error = 1;
				fbreak;
			}
			memcpy(item->node.value.string, string, len);
			item->node.name = NULL;

			list_add_tail(&cur_list->node->value.list, &item->list);

			fnext list;
		} else {
			struct toml_table_item *item = malloc(sizeof(*item));

			list_add_tail(&cur_table->value.map, &item->map);
			item->node.name = name;
			item->node.type = TOML_STRING;
			item->node.value.string = malloc(len);
			if (!item->node.value.string) {
				malloc_error = 1;
				fbreak;
			}
			memcpy(item->node.value.string, string, len);
		}
	}

	action saw_date {
		struct toml_stack_item *cur_list =
						list_tail(&list_stack, struct toml_stack_item, list);

		if (cur_list) {
			if (cur_list->list_type && cur_list->list_type != TOML_DATE) {
				asprintf(&parse_error,
						"incompatible types list %s this %s line %d\n",
						toml_type_to_str(cur_list->list_type),
						toml_type_to_str(TOML_DATE), curline);
				fbreak;
			}
			cur_list->list_type = TOML_DATE;

			struct toml_list_item *item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}

			item->node.type = TOML_DATE;
			item->node.value.epoch = timegm(&tm);
			item->node.name = NULL;

			list_add_tail(&cur_list->node->value.list, &item->list);

			fnext list;
		} else {
			struct toml_table_item *item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}

			list_add_tail(&cur_table->value.map, &item->map);
			item->node.name = name;
			item->node.type = TOML_DATE;
			item->node.value.epoch = timegm(&tm);
		}
	}

	action start_list {
		struct toml_node *node;

		/*
		 * if the list stack is empty add this list to the table
		 * otherwise it should be added the to list on top of the stack
		 */
		if (list_empty(&list_stack)) {
			struct toml_table_item *item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}

			/* first add it to the table */
			item->node.type = TOML_LIST;
			list_head_init(&item->node.value.list);
			list_add_tail(&cur_table->value.map, &item->map);
			item->node.name = name;
			node = &item->node;
		} else {
			struct toml_stack_item *tail =
						list_tail(&list_stack, struct toml_stack_item, list);

			struct toml_list_item *item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}

			item->node.type = TOML_LIST;
			item->node.name = NULL;
			list_head_init(&item->node.value.list);

			list_add_tail(&tail->node->value.list, &item->list);
			node = &item->node;
		}

		/* push this list onto the stack */
		struct toml_stack_item *stack_item = malloc(sizeof(*stack_item));
		if (!stack_item) {
			malloc_error = 1;
			fbreak;
		}
		stack_item->node = node;
		stack_item->list_type = 0;
		list_add_tail(&list_stack, &stack_item->list);
	}

	action end_list {
		struct toml_stack_item *tail =
						list_tail(&list_stack, struct toml_stack_item, list);

		list_del(&tail->list);
		free(tail);

		if (!list_empty(&list_stack))
			fnext list;
	}

	action saw_table {
		char *ancestor, *tofree, *tablename;

		struct toml_node *place = toml_root;

		tofree = tablename = strndup(ts, (int)(p-ts));

		while ((ancestor = strsep(&tablename, "."))) {
			struct toml_table_item *item = NULL;
			int found = 0;

			list_for_each(&place->value.map, item, map) {
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
			if (!item) {
				malloc_error = 1;
				fbreak;
			}
			item->node.name = strdup(ancestor);
			item->node.type = TOML_TABLE;
			list_head_init(&item->node.value.map);
			list_add_tail(&place->value.map, &item->map);

			place = &item->node;
		}

		if (place->type != TOML_TABLE) {
			asprintf(&parse_error, "Attempt to overwrite table %.*s",
															(int)(p-ts), ts);
			fbreak;
		}

		free(tofree);

		cur_table = place;
	}

	action saw_table_array {
		char *ancestor, *tofree, *tablename;

		struct toml_node *place = toml_root;
		struct toml_list_item *new_table_entry = NULL;

		tofree = tablename = strndup(ts, (int)(p-ts-1));

		while ((ancestor = strsep(&tablename, "."))) {
			struct toml_table_item *item = NULL;
			int found = 0;

			list_for_each(&place->value.map, item, map) {
				if (strcmp(item->node.name, ancestor) == 0) {
					place = &item->node;
					found = 1;
					break;
				}
			}

			if (found)
				continue;

			/* this is the auto-vivification */

			/*
			 * Create a table array node and insert it into the heirarchy
			 */
			item = malloc(sizeof(*item));
			if (!item) {
				malloc_error = 1;
				fbreak;
			}
			item->node.name = strdup(ancestor);
			item->node.type = TOML_TABLE_ARRAY;
			list_head_init(&item->node.value.list);
			list_add_tail(&place->value.map, &item->map);

			place = &item->node;
		}

		if (place->type != TOML_TABLE_ARRAY) {
			asprintf(&parse_error, "Attempt to overwrite table %.*s",
															(int)(p-ts), ts);
			fbreak;
		}

		free(tofree);

		/*
		 * Create a table which becomes the last element in the list
		 * of maps (table array is a list of maps)
		 */
		new_table_entry = malloc(sizeof(*new_table_entry));
		if (!new_table_entry) {
			malloc_error = 1;
			fbreak;
		}

		new_table_entry->node.type = TOML_TABLE;
		new_table_entry->node.name = NULL;
		list_head_init(&new_table_entry->node.value.map);
		list_add_tail(&place->value.list, &new_table_entry->list);

		cur_table = &new_table_entry->node;
	}

	action saw_comment {
		if (!list_empty(&list_stack))
			fnext list;

		curline++;
	}

	action saw_utf16 {
		UChar		utf16[2] = { 0 };
		int32_t		len = sizeof(string) - (strp - string);
		int32_t		outLen;
		UErrorCode	err = U_ZERO_ERROR;
		char		utf16_str[5] = { 0 };

		memcpy(utf16_str, utf_start, 4);
		*utf16 = strtoul(utf16_str, NULL, 16);

		u_strToUTF8(strp, len, &outLen, utf16, 1, &err);
		strp += outLen;
		fret;
	}

	action saw_utf32 {
		uint32_t	utf32;
		int32_t		len = sizeof(string) - (strp - string);
		int32_t		outLen;
		char		utf32_str[9] = { 0 };

		memcpy(utf32_str, utf_start, 8);
		utf32 = strtoul(utf32_str, NULL, 16);

		outLen = utf32ToUTF8(strp, len, utf32);
		strp += outLen;
		fret;
	}

	lines = (
		start: (
			# count the indentation to know where the tables end
			[\t ]* >{ indent = 0; } ${ indent++; } ->text
		),

		# just discard everything until newline
		comment: ( [^\n]*[\n] @saw_comment ->start ),

		# a table
		table: (
			name ']' @saw_table					->start	|
			'[' name ']' ']' @saw_table_array	->start
			),

		# the boolean data type
		true:	( any	>{fhold;} $saw_bool	->start ),
		false:	( any 	>{fhold;} $saw_bool	->start ),

		basic_string: (
			["]					-> basic_empty_or_multi_line	|
			[^"] ${fhold;}		-> basic_string_contents
		),

		basic_empty_or_multi_line: (
			["]					-> basic_multi_line_start	|
			[^"] $saw_string	-> start
		),

		basic_multi_line_start: (
			'\n' ${curline++;}	-> basic_multi_line |
			[^\n] ${fhold;}		-> basic_multi_line
		),

		basic_multi_line: (
			["]										-> basic_multi_line_quote	|
			[\n]		${curline++;*strp++=fc;}	-> basic_multi_line			|
			[\\]									-> basic_multi_line_escape	|
			[^"\n\\]	${*strp++=fc;}				-> basic_multi_line
		),

		basic_multi_line_escape: (
			[\n]	${curline++;}			-> basic_multi_line_rm_ws	|
			[^\n]	${fcall str_escape;}	-> basic_multi_line
		),

		basic_multi_line_rm_ws: (
			[\n]	${curline++;}	-> basic_multi_line_rm_ws |
			[ \t]					-> basic_multi_line_rm_ws |
			[^ \t\n]	${fhold;}	-> basic_multi_line
		),

		basic_multi_line_quote: (
			["]								-> basic_multi_line_quote_2	|
			[^"]	${fhold;*strp++='"';}	-> basic_multi_line
		),

		basic_multi_line_quote_2: (
			["]		$saw_string							-> start |
			[^"]	${fhold;*strp++='"';*strp++='"';}	-> basic_multi_line
		),

		# String, we have to escape \0, \t, \n, \r, everything else can
		# be prefixed with a slash and the slash just gets dropped
		basic_string_contents: (
			'"'			$saw_string					-> start					|
			[\n]		${curline++; *strp++=fc;}	-> basic_string_contents	|
			[\\]		${fcall str_escape;}		-> basic_string_contents	|
			[^"\n\\]	${*strp++=fc;}				-> basic_string_contents
		),

		str_escape: (
			'b'	${*strp++=0x8;}			${fret;}	|
			't'	${*strp++='\t';}		${fret;}	|
			'n'	${*strp++='\n';}		${fret;}	|
			'f'	${*strp++=0xc;}			${fret;}	|
			'r'	${*strp++='\r';}		${fret;}	|
			'0'	${*strp++=0;}			${fret;}	|
			'x'							-> hex_byte	|
			'u'							-> unicode4	|
			'U'							-> unicode8	|
			[^btnfr0xuU] ${*strp++=fc;}	${fret;}
		),

		hex_byte: (
			xdigit{2} >{hex[0]=*p;}
				@{hex[1]=*p; *strp++=strtoul(hex, NULL, 16); fret;}
		),

		unicode4: (
			xdigit{4} >{utf_start=p;} @saw_utf16
		),

		unicode8: (
			xdigit{8} >{utf_start=p;} @saw_utf32
		),

		# A sign can optiionally prefix a number
		sign: (
			'-' ${sign = -1;}	->number |
			'+' ${sign = 1;}	->number
		),
		number: (
			digit ${number *= 10; number += fc - '0';}	->number			|
			'.'	${floating = number; dec_pos = 10;}		->fractional_part	|
			[\n] ${curline++;} $saw_int					->start				|
			[^0-9.]	$saw_int							->start
		),

		# When we don't know yet if this is going to be a date or a number
		# this is the state
		number_or_date: (
			digit ${number *= 10; number += fc - '0';}	->number_or_date	|
			'-'	${tm.tm_year = number - 1900;}			->date				|
			'.'	${floating = number * sign; dec_pos = 10;}			->fractional_part	|
			[\n] ${curline++;} $saw_int								->start	|
			[\t ,\]] $saw_int										->start
		),

		# Fractional part of a double
		fractional_part: (
			[0-9] 	$float_add_place	->fractional_part |
			[^0-9]  $saw_float			->start
		),

		# Zulu date, we've already picked up the first four digits and the '-'
		# when figuring this was a date and not a number
		date: (
			digit{2} @{tm.tm_mon = atoi(fpc-1) - 1;}
			'-'
			digit{2} @{tm.tm_mday = atoi(fpc-1);}
			'T'
			digit{2} @{tm.tm_hour = atoi(fpc-1);}
			':'
			digit{2} @{tm.tm_min = atoi(fpc-1);}
			':'
			digit{2} @{tm.tm_sec = atoi(fpc-1);}
			'Z' @saw_date ->start
		),

		literal_string: (
			[']					-> literal_empty_or_multi_line		|
			[^']	${fhold;}	-> literal_string_contents
		),

		literal_string_contents: (
			[']		$saw_string		->start						|
			[^']	${*strp++=fc;}	->literal_string_contents
		),

		literal_empty_or_multi_line: (
			[']								-> literal_multi_line_start	|
			[^']	${fhold;} $saw_string	-> start
		),

		literal_multi_line_start: (
			'\n' ${curline++;}	-> literal_multi_line |
			[^\n] ${fhold;}		-> literal_multi_line
		),

		literal_multi_line: (
			[']									-> literal_multi_line_quote	|
			[\n]	${curline++;*strp++=fc;}	-> literal_multi_line		|
			[^'\n]	${*strp++=fc;}				-> literal_multi_line
		),

		# saw 1 quote, if there's not another one go back to literalMultiLine
		literal_multi_line_quote: (
			[']									-> literal_multi_line_second_quote |
			[^']	${fhold;*strp++='\'';}		-> literal_multi_line
		),

		# saw 2 quotes, if there's not another one go back to literalMultiLine
		# if there is another then terminate the string
		literal_multi_line_second_quote: (
			[']		$saw_string								-> start				|
			[^']	${fhold;*strp++='\'';*strp++='\'';}		-> literal_multi_line
		),

		# Non-list value
		singular: (
			'true'	@{number = 1;}				-> true				|
			'false'	@{number = 0;}				-> false			|
			'"'		${strp = string;}			-> basic_string	|
			[']		${strp = string;}			-> literal_string	|
			('-'|'+') ${fhold;number = 0;}		-> sign				|
			digit ${sign = 1;fhold;number = 0;}	-> number_or_date
		),

		# A list of values
		list: (
			'#'								->comment	|
			'\n' ${ curline++; }			->list		|
			[\t ]							->list		|
			','								->list		|
			']'	$end_list					->start		|
			[^#\t, \n\]] ${fhold;}			->val
		),

		# A val can be either a list or a singular value
		val: (
			'#'							->comment	|
			'\n' ${ curline++; }		->val		|
			[\t ]						->val		|
			'[' $start_list				->list		|
			']'	$end_list				->start		|
			[^#\t \n[\]] ${fhold;}		->singular
		)

		# A regular key
		key: (
			name  whitespace >{namelen = (int)(p-ts);} '=' $saw_key ->val
		),

		# Text stripped of leading whitespace
		text: (
			'#'							->comment	|
			'['							->table		|
			[\t ]						->text		|
			'\n' ${curline++;}			->start     |
			[^#[\t \n,\]]	${fhold;}	->key
		)
	);

	main := lines?;
}%%

%%write data;

int
toml_parse(struct toml_node *toml_root, char *buf, int buflen)
{
	int indent = 0, cs, curline = 1;
	char *p, *pe;
	char *ts;
	char string[1024], *strp;
	int sign, number, dec_pos, namelen;
	struct tm tm;
	double floating;
	char *name;
	char *parse_error = NULL;
	char hex[3] = { 0 };
	int malloc_error = 0;
	char* utf_start;
	int top = 0, stack[1024];

	struct toml_node *cur_table = toml_root;

	struct list_head list_stack;
	list_head_init(&list_stack);

	assert(toml_root->type == TOML_ROOT);

	%% write init;

	p = buf;
	pe = buf + buflen;

	%% write exec;

	if (malloc_error) {
		fprintf(stderr, "malloc failed, line %d\n", curline);
		return 1;
	}

	if (parse_error) {
		fprintf(stderr, "%s at %d p = %.5s\n", parse_error, curline, p);
		free(parse_error);
		return 1;
	}

	if (cs == toml_error) {
		fprintf(stderr, "PARSE_ERROR, line %d, p = '%.5s'", curline, p);
		return 1;
	}

	return 0;
}
