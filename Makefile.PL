use inc::Module::Install;
name 'JSTAPd';
all_from 'lib/JSTAPd.pm';

requires 'HTTP::Engine';
requires 'Data::Dumper';
requires 'JSON::XS';
requires 'HTTP::Request';
requires 'LWP::UserAgent';
requires 'Path::Class';
requires 'Time::HiRes';
requires 'Data::UUID';
requires 'Test::TCP';
requires 'FindBin';

install_script "scripts/jstapd";

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
