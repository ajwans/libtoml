#include <stdlib.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "CUnit/Basic.h"
#include "toml.h"

static int
init_toml(void)
{
	return 0;
}

static int
fini_toml(void)
{
	return 0;
}

static void
testFruit(void)
{
	int					ret;
	struct toml_node	*root;
	char				*fruit =
				"[fruit]\ntype = \"apple\"\n\n[fruit.type]\napple = \"yes\"\n";

	toml_init(&root);

	ret = toml_parse(root, fruit, strlen(fruit));
	CU_ASSERT(ret);

	toml_free(root);
}

static void
testTypes(void)
{
	int					ret;
	struct toml_node	*root;
	char				*types = "list = [ 1, \"string\" ]\n";

	toml_init(&root);

	ret = toml_parse(root, types, strlen(types));
	CU_ASSERT(ret);

	toml_free(root);
}

static void
testHex(void)
{
	int					ret;
	struct toml_node	*node;
	struct toml_node	*root;
	char				*string_with_hex = "string_with_hex = \"\\x4bfoo\"\n";

	toml_init(&root);

	ret = toml_parse(root, string_with_hex, strlen(string_with_hex));
	CU_ASSERT(ret == 0);

	node = toml_get(root, "string_with_hex");
	CU_ASSERT(node != NULL);
	CU_ASSERT(node->type == TOML_STRING);

	CU_ASSERT(strcmp(node->value.string, "Kfoo") == 0);

	toml_free(root);
}

static void
mmapAndParse(char *path, int expected)
{
	int					fd, ret;
	struct toml_node	*root;
	void				*m;
	struct stat			st;

	toml_init(&root);

	fd = open(path, O_RDONLY);
	CU_ASSERT_FATAL(fd != -1);

	ret = fstat(fd, &st);
	CU_ASSERT_FATAL(ret != -1);

	m = mmap(NULL, st.st_size, PROT_READ, MAP_FILE|MAP_PRIVATE, fd, 0);
	CU_ASSERT_FATAL(m != NULL);

	ret = toml_parse(root, m, st.st_size);
	CU_ASSERT(ret == expected);

	munmap(m, st.st_size);
	close(fd);
	toml_free(root);
}

static void
testGoodExamples(void)
{
	mmapAndParse("examples/example.toml", 0);
	mmapAndParse("examples/hard_example.toml", 0);
}

static void
testBadExamples(void)
{
	mmapAndParse("examples/text_after_array.toml", 1);
	mmapAndParse("examples/text_after_table.toml", 1);
	mmapAndParse("examples/text_after_value.toml", 1);
	mmapAndParse("examples/text_in_array.toml", 1);
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

	if ((NULL == CU_add_test(pSuite, "test hex", testHex)))
		goto out;

	if ((NULL == CU_add_test(pSuite, "test good examples", testGoodExamples)))
		goto out;

	if ((NULL == CU_add_test(pSuite, "test bad examples", testBadExamples)))
		goto out;

	CU_basic_set_mode(CU_BRM_VERBOSE);
	CU_basic_run_tests();

out:
	CU_cleanup_registry();
	exit(CU_get_error());
}
