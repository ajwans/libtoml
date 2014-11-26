libtoml
=======

Fast C parser using Ragel to generate the state machine.

Currently targetted at TOML v0.2.0

Usage
=====

```c
#include <toml.h>

struct toml_node *root;
struct toml_node *node;
char *buf = "[foo]\nbar = 1\n";

toml_init(&root);
toml_parse(toml_root, buf, len);

node = toml_get(toml_root, "foo.bar");

toml_dump(toml_root, stdout);
toml_free(root);
```

Building it
===========

Building libtoml requires ragel (the parser generator) and libicu for unicode support.

```sh
> autoconf
> ./configure
> make
```

If you want to run the tests

```sh
> ./configure --with-cunit=<path_to_cunit>
> make test
> ./test
```

Testing it
==========

Compatible with [toml-test](https://github.com/BurntSushi/toml-test) when invoked
as 'parser_test'

```sh
> $GOPATH/bin/toml-test $PWD/parser_test
```

TODO
====

More tests
