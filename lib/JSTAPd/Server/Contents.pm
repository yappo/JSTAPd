package JSTAPd::Server::Contents;
use strict;
use warnings;
use Plack::Response;
use Data::UUID;

sub handler {
    my($class, $path, $server, $req, $session, $args) = @_;

    my @chain  = split '/', $path;
    my $method = pop @chain;
    my $klass  = join '::', __PACKAGE__, @chain;

    if (@chain && $chain[0] eq 'contents') {
        shift @chain;
        $klass  = 'JSTAPd::Server::Contents::contents';
        $method = join '/', @chain, $method;
    } else {
        no strict 'refs';
        eval 'require $klass' unless %{"$klass\::"}; ## no critic
    }
    unless (!$@ && ($klass->can($method) || $klass->can('AUTOLOAD'))) {
        return Plack::Response->new(404, [ 'Content-Type' => 'text/plain' ], 'Not Found' );
    }
    warn "$klass -> $method : " . $req->uri unless $server->run_once;
    $klass->$method($server, $req, $session, $args);
}

# index page
sub index {
    my($class, $server, $req, $session) = @_;
    return Plack::Response->new(
        200, 
        [ 'Content-Type' => 'text/html' ],
        JSTAPd::Contents->build_index(
            jstapd_prefix => $server->jstapd_prefix,
            run_once      => $server->run_once,
            auto_open     => $server->auto_open,
        )
    );
}

package JSTAPd::Server::Contents::contents;
use JSON::XS ();

sub AUTOLOAD {
    my($class, $server, $req, $session, $args) = @_;
    my $path = our $AUTOLOAD;
    $path =~ s/.+:://;
    my @chain = split '/', $path;
    my $basename = pop @chain;

    if ($basename eq 'index') {
        return _index(@_, \@chain);
    }

    # foo.t
    $server->setup_session_tap($session, $path);
    $server->set_tests($session, $path);

    my $content = $server->contents->fetch_file($basename, \@chain);

    if ($args->{is_api}) {
        return __run_api($content, $server, $req, $session, $args);
    }

    my @include = map {
        ref($_) eq 'SCALAR' ? sprintf "include('/%s/share/js/%s')", $server->jstapd_prefix, ${ $_ } : "include('$_')"
    } $content->suite->include_ex, $content->suite->include;

    my $index   = $server->contents->fetch_file('index', \@chain, 1);
    return Plack::Response->new(
        200,
        [ 'Content-Type' => 'text/html' ],
        $index->build_html(
            $content->header(
                jstapd_prefix => $server->jstapd_prefix,
                session       => $session,
                path          => $path,
                include       => join('.', @include),
            ),
            $content->suite->html_body,
        ),
    );
}

sub __run_api {
    my($content, $server, $req, $session, $args) = @_;
    my $tap = $server->get_tap($session, $args->{path});

    my $GLOBAL = $tap->global_stash;
    my $METHOD = $req->method;
    my $PATH   = $req->uri->path;

    my $ret;
    my $err;
    do {
        local $@;
        eval {
            $ret = $content->suite->server_api(
                $tap->global_stash,
                $req,
                $req->method,
                $req->uri->path,
            );
        };
        $err = $@;
    };
    if ($err) {
        my $body = sprintf "error: %s\n\t%s\n", $args->{path}, $err;
        warn $body;
        return Plack::Response->new(500, [ 'Content-Type' => 'text/plain' ], $body );
    }
    if (ref($ret)) {
        return Plack::Response->new(200, [ 'Content-Type' => 'application/json' ], JSON::XS->new->ascii->encode($ret) );
    } else {
        return Plack::Response->new(200, [ 'Content-Type' => 'text/plain' ], $ret );
    }
}

package JSTAPd::Server::Contents::js;

sub AUTOLOAD {
    my($class, $server, $req, $session, $args) = @_;
    my $path = our $AUTOLOAD;
    $path =~ s/.+:://;
    $path =~ s/\.js$//;
    $path =~ s/-/_/;

    my $body;
    $body = $class->$path if $class->can($path);
    return Plack::Response->new( 404, [ 'Content-Type' => 'text/plain' ], 'Not Found' ) unless $body;
    return Plack::Response->new( 200, [ 'Content-Type' => 'text/plain' ], $body );
}

1;

