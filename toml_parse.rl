#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include "toml.h"

%%{
	machine toml;

	action a_boolean	{
		printf("got boolean %.*s\n", ts[0] == 't' ? 4 : 5, ts);
		fret;
	}

	action a_integer	{ 
		int64_t integer = strtol(ts, NULL, 10);
		printf("%d got integer %"PRId64"\n", cs, integer); 
		printf("stack top is %d -> %d\n", top - 1, stack[top - 1]);
		printf("p = '%.5s'\n", p);
		fret;
	}

	action a_float		{ 
		double floating = strtod(ts, NULL);
		printf("got float %lf\n", floating); fret;
	}

	action a_string		{
		printf("got string %.*s\n", (int)(te-ts), ts);
		fret;
	}

	action a_date		{
		struct tm tm;
		time_t t;

		sscanf(ts, "%4d-%2d-%2dT%2d:%2d:%2dZ", &tm.tm_year, &tm.tm_mon,
						&tm.tm_mday, &tm.tm_hour, &tm.tm_min, &tm.tm_sec);

		tm.tm_year -= 1900;
		tm.tm_mon -= 1;
		tm.tm_zone = "UTC";
		tm.tm_gmtoff = 0;

		t = timegm(&tm);
		printf("got date %d\n", (int)t);

		printf("p = '%.5s'\n", p);

		fret;
	}

	#utf8 := print - '"' @return;
	whitespace = ([\t ]* ${ printf("got ws char %d cs = %d p = %p p5 = '%.5s' nacts = %d\n", *p, cs, p, p, _nacts); });

	boolean = ('true'|'false');
	string	= '"' (print - '"')* '"';
	integer	= [+\-]?digit+;
	float	= [+\-]?digit+ '.' digit+;
	date	= digit{4} '-' digit{2} '-' digit{2} 'T' digit{2} ':' digit{2} ':'
				digit{2} 'Z';
	log = any ${printf("log got '%.5s'\n", p);};

	value := |*
		boolean => a_boolean;
		string	=> a_string;
		float	=> a_float;
		integer	=> a_integer;
		date	=> a_date;
	*|;

	comment = '#' [^\n]* %{ printf("got comment on %d\n", curline); };

	key = (print - (whitespace|']'))+ >{key = p;} %{ printf("key is %.*s\n", (int)(1+p-key), key);};

	nl = '\n' @{ printf("got newline\n"); curline += 1; };

	line = (
		start: (
			[\t ]* >{ indent = 0; } ${ indent++; } ->text
		),

		text: (
			'#'	@{fhold;}			->final		|
			'[' 					->map		|
			[\t ]					->text		|
			'\n' %{fhold;}			->final		|
			[^#[\t \n] @{fhold;}	->keyval	|
			''						->final
		),

		map: (
			key ']' ->text
		),

		aval: (
			'true'			-> true				|
			'false'			-> false			|
			'"' 			-> string			|
			'-'				-> negative_number	|
			'+'				-> number			|
			digit			-> number_or_date
		),

#		aval: (
#			any >{
#				printf("cs %d fcurs %d entering value p = '%.5s'\n", cs, fcurs, p);
#				fcall value;
#			}
#		   	->final
#		),

		newlist: (
			[\t ]+						->newlist	|
			[^\t \]] >{fcall value;}	->list		|
			']'							->text
		),

		val: (
			'['													->newlist	|
			'\n' @{fhold;}										->text		|
			[^[\n] >{fhold;printf("entering aval p = '%.5s'\n", p);}	->aval
		),

		list: (
			[\t ]+					->list	|
			','						->list 	|
			']'						->text  |
			[^\t ,\]] >{fhold;}		->val
	  	)

		keyval: (
			key whitespace '=' @{printf("got equals\n");} whitespace !whitespace >{printf("not whitespace p='%.5s'\n", p);}->val
		)
	);

	main := (line comment? nl)*;
}%%

%%write data;

int
toml_parse(struct toml_node *toml_root, char *buf, int buflen)
{
	int indent = 0, cs, act, curline = 0;
	int stack[100], top;
	char *ts, *te, *eof = NULL, *p, *pe;
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
