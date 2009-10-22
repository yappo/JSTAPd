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

    my $in_the_parse = do {
        no strict 'refs';
        ${"$caller\::IN_THE_PARSE"};
    };

    strict->import;
    warnings->import;
    if ($in_the_parse) {
        return;
    }

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
        ($ENV{JSTAP_HOST} ? (host => $ENV{JSTAP_HOST}) : ()),
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


sub export {
    my $class = shift;

    do {
        no strict 'refs';
        *{"$class\::new"} = \&new;
    };

    # set default method
    for my $method (qw/ client_script html_body server_api /) {
        next if $class->can($method);
        no strict 'refs';
        *{"$class\::$method"} = sub { '' };
    }

    for my $method (qw/ include include_ex /) {
        next if $class->can($method);
        no strict 'refs';
        *{"$class\::$method"} = sub { +() };
    }

}

sub new {
    my $class = shift;
    bless {}, $class;
}

1;
