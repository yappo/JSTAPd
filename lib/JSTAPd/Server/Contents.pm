use strict;
use warnings;
package JSTAPd::Server::Contents;
use HTTP::Engine::Response;
use Data::UUID;

sub handler {
    my($class, $path, $server, $req, $session) = @_;

    my @chain  = split '/', $path;
    my $method = pop @chain;
    my $klass  = join '::', __PACKAGE__, @chain;

    if (@chain && $chain[0] eq 'contents') {
        shift @chain;
        $klass  = 'JSTAPd::Server::Contents::contents';
        $method = join '/', @chain, $method;
    } else {
        no strict 'refs';
        eval 'require $klass' unless %{"$klass\::"};
    }
    unless (!$@ && ($klass->can($method) || $klass->can('AUTOLOAD'))) {
        return HTTP::Engine::Response->new( status => 404, body => 'Not Found' );
    }
    warn "$klass -> $method";
    $klass->$method($server, $req, $session);
}

# index page
sub index {
    my($class, $server, $req, $session) = @_;
    HTTP::Engine::Response->new( body => JSTAPd::Contents->build_index( jstapd_prefix => $server->jstapd_prefix ) );
}

package JSTAPd::Server::Contents::contents;

sub _gen_li {
    my $path = shift;
    sprintf '<li><a href="%s">%s</a></li>', $path, $path;
}
sub _index {
    my($class, $server, $req, $session, $chain) = @_;

    my @li = _gen_li('../');
    $server->contents->each( $chain => sub {
        my($name, $is_dir) = @_;
        return if $name eq 'index';
        push @li, $is_dir ? _gen_li("$name/") : _gen_li($name);
    });

    my $index = $server->contents->fetch_file('index', $chain, 1);
    my $body = sprintf "<ul>\n%s</ul>\n", join("\n", @li);
    HTTP::Engine::Response->new( body => $index->build_html( '', $body ) );
}

sub AUTOLOAD {
    my($class, $server, $req, $session) = @_;
    my $path = our $AUTOLOAD;
    $path =~ s/.+:://;
    my @chain = split '/', $path;
    my $basename = pop @chain;

    if ($basename eq 'index') {
        return _index(@_, \@chain);
    }

    # foo.jstap
    $server->setup_session_tap($session, $path);

    my $index   = $server->contents->fetch_file('index', \@chain, 1);
    my $content = $server->contents->fetch_file($basename, \@chain);

    return HTTP::Engine::Response->new(
        body => $index->build_html(
            $content->header(
                jstapd_prefix => $server->jstapd_prefix,
                session       => $session,
                path          => $path,
            ),
            $content->body,
        ),
    );
}

1;

