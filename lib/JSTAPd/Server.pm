package JSTAPd::Server;
use strict;
use warnings;
use Data::Dumper;
use JSON::XS;
use HTTP::Engine;
use Path::Class;

use JSTAPd::ContentsBag;
use JSTAPd::Server::Contents;
use JSTAPd::TAP;

sub contents { $_[0]->{contents} }
sub conf { $_[0]->{conf} }
sub jstapd_prefix { $_[0]->{conf}->{jstapd_prefix} }

sub new {
    my($class, %opts) = @_;

    my $self = bless {
        dir  => '.',
        port => 1978,
        host => '127.0.0.1',
        session_tap => +{},
        %opts,
    }, $class;
    $self->{dir} = Path::Class::Dir->new( $self->{dir} );
    $self->{contents} = JSTAPd::ContentsBag->new( dir => $self->{dir} );
    $self->{contents}->load;
    $self->load_config;
    $self;
}

sub load_config {
    my $self = shift;
    my $path = $self->{dir}->file('conf.pl');
    my $hash = do $path;
    if (defined $hash && ref($hash) ne 'HASH') {
        die "$path return data is not HASHref";
    }
    $hash ||= +{};

    $self->{conf} = {
        jstapd_prefix => '____jstapd',
        urlmap       => +[],
        %{ $hash },
    };
}

sub run {
    my $self = shift;

    $self->{engine} = HTTP::Engine->new(
        interface => {
            module => 'ServerSimple',
            args   => {
                host => $self->{host},
                port => $self->{port},
            },
            request_handler => sub {
                $self->handler(@_);
            },
        },
    );
    warn sprintf 'starting: http://%s:%s/%s/', $self->{host}, $self->{port}, $self->{conf}->{jstapd_prefix};
    $self->{engine}->run;
}

sub setup_session_tap {
    my($self, $session, $path) = @_;
    $self->{session_tap}->{$session} ||= +{
        current_path => undef,
        path         => +{},
    };
    if ($path) {
        return $self->{session_tap}->{$session}->{path}->{$path} ||= +{
            is_end => 0,
            tap    => JSTAPd::TAP->new,
        };
    } else {
        return $self->{session_tap}->{$session};
    }
}
sub get_session {
    $_[0]->setup_session_tap($_[1]);
}
sub get_path {
    $_[0]->setup_session_tap($_[1], $_[2]);
}
sub get_tap {
    $_[0]->get_path($_[1], $_[2])->{tap};
}

sub decode_urlmap {
    my($self, $path) = @_;
    my $urlmap = $self->{conf}->{urlmap};
    for my $conf (@{ $urlmap }) {
        my($re, $new) = %{ $conf };
        last if $path =~ s/$re/$new/;
    }
    $path;
}

sub handler {
    my($self, $req) = @_;
    my $session = $req->param('session') || Data::UUID->new->create_hex;

    my $jstapd_prefix = $self->{conf}->{jstapd_prefix};
    my $res;
    if (my($path) = $req->uri->path =~ m!^/$jstapd_prefix/(.+)?$!) {
        # serve jstapd contents
        $path = 'index' unless $path;
        $path .= 'index' if $path =~ m!/$! || !$path;
        $res = JSTAPd::Server::Contents->handler($path, $self, $req, $session);
    } elsif (($path) = $req->uri->path =~ m!^/${jstapd_prefix}__api/(.+)?$!) {
        # ajax request
        $res = $self->api_handler($path, $req, $session);
        $res ||= HTTP::Engine::Response->new( status => 200, body => '{msg:"ok"}' );
    } elsif ($req->uri->path eq '/favicon.ico') {
    } else {
        # ajax request?
        my $path = $self->decode_urlmap($req->uri->path);
        $res = HTTP::Engine::Response->new( status => 200, body => $self->{dir}->file($path)->slurp.'' );
    }
    return $res || HTTP::Engine::Response->new( status => 404, body => 'Not Found' );
}

sub api_handler {
    my($self, $type, $req, $session) = @_;

    # for main index
    my $current_path = $self->get_session($session)->{current_path};
    if ($type eq 'get_next') {
        my $next_current = -1;
        my $is_next = $current_path ? 0 : 1;
        my $is_last = 0;
        $self->{contents}->visitor(sub{
            return if $is_last;
            my $args = shift;
            return if $args->{is_dir};
            return unless $args->{name} =~ /\.jstap$/;
            if ($is_next) {
                $next_current = $args->{path};
                $is_last++;
                return;
            }
            if ($current_path eq $args->{path}) {
                $is_next++;
            }
        });
        $self->get_session($session)->{current_path} = $current_path = $next_current;
        return $self->json_response(+{
            session => $session,
            path    => "$current_path",
        });
    } elsif ($type eq 'watch_finish') {
        my @session_path = ($session, $current_path);
        if ($current_path && $self->get_path(@session_path)->{is_end}) {
            my $tap = $self->get_tap(@session_path);
            return $self->json_response({
                session => $session,
                path    => $current_path,
                tap     => $tap->as_hash,                
            });
        } else {
            return $self->json_response({
                status => 0,
            });
        }
    }


    # for tap test
    my $path = $req->param('path');
    my @session_path = ($session, $path);

    my $tap = $self->get_tap(@session_path);
    if ($type eq 'tests') {
        $tap->tests($req->param('num'));
    } elsif ($type eq 'tap') {
        $tap->push_tap($req->params);
    } elsif ($type eq 'tap_done') {
        if (my $error = $req->param('error')) {
            $tap->error($error);
        }
        $self->get_path(@session_path)->{is_end} = 1;
        return HTTP::Engine::Response->new( status => 200, body => $tap->as_string );
    } elsif ($type eq 'dump') {
        warn Dumper($tap);
    }
    return;
}

sub json_response {
    HTTP::Engine::Response->new( body => JSON::XS->new->ascii->encode($_[1]) );
}

1;
