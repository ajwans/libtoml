#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include "toml.h"

%%{
	machine toml;

	action ResetIndent {
		indent = 0;
	}
	action CountIndent {
		indent++;
	}
	action Indented {
		printf("indent is %d on %d\n", indent, curline);
	}

	action return { fret; }

	action a_boolean	{
		printf("got boolean %.*s\n", ts[0] == 't' ? 4 : 5, ts);
		fret;
	}

	action a_integer	{ 
		int64_t integer = strtol(ts, NULL, 10);
		printf("got integer %"PRId64"\n", integer); 
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

	action a_list		{ printf("got a list cs = %d\n", cs); fret; }

	utf8 := print - '"' @return;
	whitespace = ([\t ]* ${ printf("got ws char %d cs = %d p = %p p5 = '%.5s' nacts = %d\n", *p, cs, p, p, _nacts); });

	boolean = ('true'|'false');
	string	= '"' (print - '"')* '"';
	integer	= [+\-]?digit+;
	float	= [+\-]?digit+ '.' digit+;
	date	= digit{4} '-' digit{2} '-' digit{2} 'T' digit{2} ':' digit{2} ':'
				digit{2} 'Z';

#	value = (boolean|integer|float|string|date);
#		list	=> a_list;

	action call_value1 {
		printf("1cs %d, fcurs %d, p %d\n", cs, fcurs, *p);
		printf("1stack top is %d -> %d\n", top-1, stack[top-1]);
		printf("1value is state %d\n", fentry(value));
		stack[top++] = cs;
		fgoto value;
	}
	action call_value2 {
		printf("2cs %d, fcurs %d, p %d\n", cs, fcurs, *p);
		printf("2stack top is %d -> %d\n", top-1, stack[top-1]);
		printf("2value is state %d\n", fentry(value));
		stack[top++] = cs;
		fgoto value;
	}

#list_item = (whitespace %call_value) whitespace;
	list = '[' %{printf("got open list\n");} (whitespace |
			whitespace :> !whitespace >call_value1 whitespace
			(',' >{printf("got comma\n");} whitespace @{printf("ws3\n");} :> !whitespace >call_value2 whitespace >{printf("ws4\n");})*)?
		']';

#(whitespace %call_value whitespace (',' whitespace %call_value whitespace)* )? whitespace ']';
	value := |*
		boolean => a_boolean;
		string	=> a_string;
		float	=> a_float;
		integer	=> a_integer;
		date	=> a_date;
#'[' (whitespace | whitespace @call_value1 whitespace
#				(',' %{printf("got comma\n");} whitespace @call_value2 whitespace)*) ']' {};
		list	=> a_list;
#list;
	*|;

	comment = '#' [^\n]* %{ printf("got comment on %d\n", curline); };

	key = (print - (whitespace|']'))+ >{ ts = p; } %{ snprintf(key, 1+ p - ts, "%s", ts); };

	indentation = whitespace >ResetIndent $CountIndent @Indented;

	nl = '\n' @{ printf("got newline\n"); curline += 1; };

	line = (
		whitespace comment %{
			printf("comment on %d\n", curline);
		} |

		whitespace %{
			printf("empty line on %d\n", curline);
		} |

		indentation '[' whitespace key whitespace ']' whitespace comment? %{
			printf("map [%s] on %d\n", key, curline);
		} |

		indentation whitespace key whitespace ('=' %{ printf("got equals\n"); } ) whitespace >{printf("entering ws1\n");} :> !whitespace >{fcall value;} whitespace >{printf("entering ws2 p = %d\n", *p);} comment? >{printf("entering comment p = %d\n", *p);} %{
			printf("key %s on %d\n", key, curline);
		}
	);

	main := (line nl)*;
}%%

%%write data;

int
toml_parse(struct toml_node *toml_root, char *buf, int buflen)
{
	int indent = 0, cs, act, curline = 0;
	int stack[100], top;
	char *ts, *te, *eof = NULL, *p, *pe;
	char key[100];

	assert(toml_root->type == TOML_ROOT);

	%% write init;

	p = buf;
	pe = buf + buflen;

	%% write exec;

	if (cs == toml_error) {
		fprintf(stderr, "PARSE_ERROR");
		return 1;
	}

	return 0;
}
