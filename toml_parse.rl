#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include "toml.h"

%%{
	machine toml;

	whitespace = ([\t ]* ${ printf("got ws char %d cs = %d p = %p p5 = '%.5s'\n", *p, cs, p, p); });

	comment = '#' [^\n]* %{ printf("got comment on %d\n", curline); };

	key = (print - (whitespace|']'))+ >{key = p;} %{ printf("key is %.*s\n", (int)(p-key), key);};

	nl = '\n' @{ printf("got newline\n"); curline += 1; };

	lines = (
		start: (
			[\t ]* >{ indent = 0; } ${ indent++; } ->text
		),

		# just discard everything until newline
		comment: ( [^\n]+[\n] ->start ),

		map: ( key ']' ->text ),

		true: ( any @{printf("TRUE\n");}			->start ),
		false: ( any @{printf("FALSE\n");}			->start ),
		string: (
			'"'  ${printf("END OF STRING\n");}		->start |
			[^"] ${printf("CHAR %c\n", *p);}		->string
		),
		negative_number: (
			digit+ -> negative_fractional_part
		),
		negative_fractional_part: (
			[.]digit+ @{printf("NEGATIVE_DECIMAL\n");}	->start
			[^.]	  @{printf("NEGATIVE_INT\n");}		->start
		),

		number_or_date: (
			digit ${printf("NOD p = '%.5s'\n", p);}	->number_or_date	|
			'-'										->date				|
			'.'										->fractional_part	|
			[\t \n,\]] @{fhold; printf("INT\n");}	->start
		),

		date: (
			digit{2} '-' digit{2} 'T' digit{2} ':' digit{2} ':' digit{2} 'Z' 
			>{printf("DATE p = '%.5s'\n", p);} @{printf("DATE\n");} ->start
		),

		fractional_part: (
			[0-9] ${printf("DECIMAL\n");}				->fractional_part |
			[^0-9]  ${printf("INT1 p = '%.5s'\n", p);}	->start
		),

		aval: (
			'true'			-> true				|
			'false'			-> false			|
			'"' 			-> string			|
			'-'				-> negative_number	|
			'+'				-> number_or_date	|
			digit >{printf("DIGIT p = '%.5s'\n", p); fhold;}	-> number_or_date
		),

		newlist: (
			[\t \n]							->newlist	|
			']'	@{printf("EMPTY LIST\n");}	->start		|
			[^\t \n\]]	>{fhold;}			->val
		),

		val: (
			[\t \n]							-> val		|
			'[' @{printf("NEWLIST\n");}		-> newlist	|
			[^\t \n[]	>{printf("AVAL p = '%.5s'\n", p);fhold;}	->aval
		)

		keyval: (
			key whitespace '=' @{printf("got equals\n");} ->val
		),

		text: (
			'#' @{printf("COMMENT\n");}					->comment	|
			'[' @{printf("MAP\n");}						->map		|
			[\t ]										->text		|
			'\n'@{printf("NEWLINE\n");}					->start     |
			','	@{printf("COMMA\n");}					->val		|
			']' @{printf("ENDLIST p = '%.5s'\n", p);}	->text		|
			[^#[\t \n,\]]	${fhold;printf("KEYVAL p = '%.5s'\n", p);}	->keyval
		)


#		aval: (
#			any >{
#				printf("cs %d fcurs %d entering value p = '%.5s'\n", cs, fcurs, p);
#				fcall value;
#			}
#		   	->final
#		),

#		newlist: (
#			[\t ]+						->newlist	|
#			[^\t \]] >{fcall value;}	->list		|
#			']'							->text
#		),
#
#		val: (
#			'['													->newlist	|
#			'\n' @{fhold;}										->text		|
#			[^[\n] >{fhold;printf("entering aval p = '%.5s'\n", p);}	->aval
#		),
#
#		list: (
#			[\t ]+					->list	|
#			','						->list 	|
#			']'						->text  |
#			[^\t ,\]] >{fhold;}		->val
#	  	)

	);

	main := lines?;
}%%

%%write data;

int
toml_parse(struct toml_node *toml_root, char *buf, int buflen)
{
	int indent = 0, cs;
	char *p, *pe;
	char *key;

	assert(toml_root->type == TOML_ROOT);

	%% write init;

	p = buf;
	pe = buf + buflen;

	%% write exec;

	if (cs == toml_error) {
		fprintf(stderr, "PARSE_ERROR, p = '%.5s'", p);
		return 1;
	}

	return 0;
}
