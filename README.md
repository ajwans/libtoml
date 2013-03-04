libtoml
=======

Fast C parser using Ragel to generate the state machine.

Currently targetted at toml b098bd2.

Usage
=====

```c
#include <toml.h>

struct toml_node *root;
struct toml_node *node;

toml_init(&root);
toml_parse(toml_root, buf, len);

node = toml_get(toml_root, "foo.bar");

toml_dump(toml_root, stdout);
toml_free(root);
```

TODO
====

More tests
