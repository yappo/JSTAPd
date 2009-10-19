use inc::Module::Install;
name 'JSTAPd';
all_from 'lib/JSTAPd.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
