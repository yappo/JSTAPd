package JSTAPd::Suite;
use strict;
use warnings;
use FindBin;
use Path::Class ();
use Test::TCP ();

use JSTAPd::Server;

sub import {
    my $class    = shift;
    my $caller   = caller;

    strict->import;
    warnings->import;

    my $suite_file = Path::Class::File->new((caller)[1]);
    my $base_dir   = detect_root($suite_file->dir);
    run_server($suite_file, $base_dir);
}

sub detect_root {
    my $path = shift;
    while (!-f $path->file('conf.pl')) {
        die 'can not detect conf.pl' if $path eq $path->parent;
        $path = $path->parent;
    }
    $path;
}

sub run_server {
    my($suite_file, $dir) = @_;
    my $port = $ENV{JSTAP_PORT} || Test::TCP::empty_port();

    JSTAPd::Server->new(
        dir      => $dir,
        host     => $ENV{JSTAP_HOST},
        port     => $port,
        run_file => $suite_file->relative($dir),
        destroy  => \&show_tap,
    )->run;
}

sub show_tap {
    my($stdout, $tap) = @_;
    print $stdout $tap->as_string;
    exit;
}

1;
