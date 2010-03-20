use inc::Module::Install;
name 'JSTAPd';
all_from 'lib/JSTAPd.pm';
githubmeta;

requires 'Plack';
requires 'Twiggy';
requires 'Data::Dumper';
requires 'JSON::XS';
requires 'HTTP::Request';
requires 'LWP::UserAgent';
requires 'Path::Class';
requires 'Time::HiRes';
requires 'Data::UUID';
requires 'Test::TCP';
requires 'FindBin';
requires 'Getopt::Long';

install_script "scripts/jstapd";

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
