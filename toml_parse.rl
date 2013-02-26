#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

	action a_boolean	{ printf("got boolean\n"); fret; }
	action a_integer	{ printf("got integer\n"); fret; }
	action a_float		{ printf("got float\n"); fret; }
	action a_string		{ printf("got string\n"); fret; }
	action a_date		{ printf("got date\n"); fret; }
	action a_list		{ printf("got a list\n"); fret; }

	utf8 := print - '"' @return;
	whitespace = ([\t ]* ${ printf("got ws char %d\n", *p); });

	boolean = ('true'|'false');
	string	= '"' (print - '"')* '"';
	integer	= [+\-]?digit+;
	float	= [+\-]?digit+ '.' digit+;
	date	= digit{4} '-' digit{2} '-' digit{2} 'T' digit{2} ':' digit{2} ':'
				digit{2} 'Z';

#	value = (boolean|integer|float|string|date);
#		list	=> a_list;

	action call_value {
		printf("current state %d\n", fcurs);
		printf("stack top is %d -> %d\n", top, stack[top]);
		stack[top++] = cs;
		fgoto value;
	}

	list_item = whitespace %call_value whitespace;
	list = '[' list_item (',' %{printf("state %d got comma\n", cs);} list_item)* ']';

#(whitespace %call_value whitespace (',' whitespace %call_value whitespace)* )? whitespace ']';
	value := |*
		boolean => a_boolean;
		string	=> a_string;
		float	=> a_float;
		integer	=> a_integer;
		date	=> a_date;
		list	=> a_list;
#list;
	*|;


	comment = '#' [^\n]* %{ printf("got comment on %d\n", curline); };
	key = (print - (whitespace|']'))+ ${ printf("key got char %c\n", *p); };

	indentation = whitespace >ResetIndent $CountIndent @Indented;

	nl = '\n' @{ printf("processed %d\n", curline); curline += 1;};

	line = (
		whitespace comment %{
			printf("comment on %d\n", curline);
		} |

		whitespace %{
			printf("empty line on %d\n", curline);
		} |

		indentation '[' whitespace key whitespace ']' whitespace comment? %{
			printf("map on %d\n", curline);
		} |

		indentation whitespace key whitespace ('=' %{ printf("got equals\n"); } ) (whitespace %{ printf("entering value\n"); fnext line; fcall value;}) whitespace comment? %{
			printf("key value on %d\n", curline);
		}
	);

	main := (line nl)*;
}%%

%%write data;

int
toml_parse(struct toml_node toml_root, int fd)
{
	int indent = 0, cs, act, curline = 0;
	int have = 0, stack[100], top;
	char buf[1024], *ts, *te, *eof = NULL;

	assert(toml_root.type != TOML_ROOT);

	%% write init;

	while (1) {
		char *p = buf + have, *pe;
		int len, space = sizeof(buf) - have;

		if (!space) {
			fprintf(stderr, "BUFFER OUT OF SPACE\n");
			exit(1);
		}

		len = read(fd, p, space);
		if (!len)
			break;

		pe = p + len;
		eof = 0;

		%% write exec;

		if (cs) {
			fprintf(stderr, "PARSE_ERROR");
			return 0;
		}

		if (ts == 0)
			have = 0;
		else {
			have = pe - ts;
			memmove(buf, ts, have);
			te = buf + (te - ts);
			ts = buf;
		}
	}

	return 0;
}
