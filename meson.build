project('libtoml', 'c')

ragel = find_program('ragel')
libicu = dependency('icu-uc')
cunit = dependency('cunit')

ragel_opts = []
if get_option('buildtype') == 'debug'
    ragel_opts += ['-n']
endif
ragel_gen = generator(ragel,
                      output : '@BASENAME@.c',
                      arguments : ragel_opts + ['-p',
                                                '-o', '@OUTPUT@',
                                                '@INPUT@'])

generated = ragel_gen.process('toml_parse.rl')

_libtoml = library('toml', 'toml.c', 'toml_private.c', generated,
                   dependencies : libicu,
                   version : '0.0.0',
                   install : true)
libtoml = declare_dependency(
    include_directories : include_directories('.'),
    link_with : _libtoml)
install_headers('toml.h')

exe_main = executable('toml', 'main.c',
                      dependencies : [libtoml, libicu],
                      install : true)

exe_test = executable('toml_test', 'test.c',
                      dependencies : [libtoml, libicu, cunit])
test('toml', exe_test)
