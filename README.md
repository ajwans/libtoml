libtoml
=======

Fast C parser using Ragel to generate the state machine.

Currently targetted at TOML v0.4.0

Usage
=====

```c
#include <toml.h>

struct toml_node *root;
struct toml_node *node;
char *buf = "[foo]\nbar = 1\n";
char *value;

toml_init(&root);
toml_parse(root, buf, len);

node = toml_get(root, "foo.bar");

toml_dump(root, stdout);

value = toml_value_as_string(node);
free(value);

toml_free(root);
```

Building it
===========

Building libtoml requires cmake, ragel (the parser generator) and libicu for unicode support.

```sh
> cmake -G "Unix Makefiles" .
> make
```

Testing it
==========

Compatible with [toml-test](https://github.com/BurntSushi/toml-test) when invoked
as 'parser_test'

```sh
> ln -s main parser_test
> $GOPATH/bin/toml-test $PWD/parser_test
```

TODO
====

More tests
