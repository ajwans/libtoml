#include <stdlib.h>

#include "CUnit/Basic.h"
#include "toml.h"

struct toml_node *root;

static int
init_toml(void)
{
	return toml_init(&root);
}

static int
fini_toml(void)
{
	toml_free(root);
	return 0;
}

static void
testFruit(void)
{
	int ret;
	char *fruit =
				"[fruit]\ntype = \"apple\"\n\n[fruit.type]\napple = \"yes\"\n";

	ret = toml_parse(root, fruit, strlen(fruit));
	CU_ASSERT(ret);
}

static void
testTypes(void)
{
	int ret;
	char *types = "list = [ 1, \"string\" ]\n";

	ret = toml_parse(root, types, strlen(types));
	CU_ASSERT(ret);
}

int main(void)
{
	CU_pSuite pSuite = NULL;

	if (CUE_SUCCESS != CU_initialize_registry())
		return CU_get_error();

	pSuite = CU_add_suite("toml suite", init_toml, fini_toml);
	if (NULL == pSuite)
		goto out;

	if ((NULL == CU_add_test(pSuite, "test fruit", testFruit)))
		goto out;

	if ((NULL == CU_add_test(pSuite, "test types", testTypes)))
		goto out;

	CU_basic_set_mode(CU_BRM_VERBOSE);
	CU_basic_run_tests();

out:
	CU_cleanup_registry();
	exit(CU_get_error());
}
