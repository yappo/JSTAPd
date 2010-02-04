package JSTAPd::Server;
use strict;
use warnings;
use Data::Dumper;
use JSON::XS;
use HTTP::Engine;
use HTTP::Request;
use LWP::UserAgent;
use Path::Class;
use Time::HiRes;

use JSTAPd::ContentsBag;
use JSTAPd::Server::Contents;
use JSTAPd::TAP;

sub contents { $_[0]->{contents} }
sub conf { $_[0]->{conf} }
sub jstapd_prefix { $_[0]->{conf}->{jstapd_prefix} }
sub run_once { !!$_[0]->{run_file} }
sub auto_open { !!$_[0]->{conf}->{auto_open_command} }

sub new {
    my($class, %opts) = @_;

    my $self = bless {
        dir  => '.',
        port => 1978,
        host => '127.0.0.1',
        session_tap => +{},
        stdout => *STDOUT,
        %opts,
    }, $class;
    $self->{dir} = Path::Class::Dir->new( $self->{dir} );
    $self->{contents} = JSTAPd::ContentsBag->new( dir => $self->{dir}, run_file => $self->{run_file} );
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

    $hash->{auto_open_command} = $ENV{JSTAP_AUTO_OPEN_COMMAND}if $ENV{JSTAP_AUTO_OPEN_COMMAND};

    $self->{conf} = {
        jstapd_prefix => '____jstapd',
        urlmap       => +[],
        apiurl       => undef,
        %{ $hash },
    };
}

sub run {
    my $self = shift;

    my $uri = sprintf 'http://%s:%s/%s/', $self->{host}, $self->{port}, $self->{conf}->{jstapd_prefix};
    if ($self->auto_open) {
        if (my $pid = fork) {
            # running to server
        } elsif (defined $pid) {
            # waiting http server startup
            while (1) {
                sleep 0.01;
                my $res = LWP::UserAgent->new->request(
                    HTTP::Request->new( GET => $uri )
                    );
                last if $res->code == 200;
            }

            # open the browser
            my $cmd = sprintf($self->conf->{auto_open_command}, $uri);
            `$cmd`;
            exit;
        } else {
            die 'browser auto open mode is fork error';
        }
    }

    $self->{engine} = HTTP::Engine->new(
        interface => {
            module => 'ServerSimple',
            args   => {
                host => $self->{host},
                port => $self->{port},
                print_banner => sub {},
            },
            request_handler => sub {
                $self->handler(@_);
            },
        },
    );
    warn "starting: $uri" unless $self->auto_open;
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
            ajax_request_stack => +[],
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
    my $apiurl        = $self->{conf}->{apiurl};
    my $res;
    if ($req->uri->path eq '/favicon.ico') {
    } elsif (my($path) = $req->uri->path =~ m!^/$jstapd_prefix/(.+)?$!) {
        # serve jstapd contents
        $path = 'index' unless $path;
        $path .= 'index' if $path =~ m!/$! || !$path;
        $self->get_session($session)->{current_path} ||= do {
            my $p = $path;
            $p =~ s{^contents/}{};
            $p;
        };
        $res = JSTAPd::Server::Contents->handler($path, $self, $req, $session);

        # no-cache
        $res->header( 'Pragma' => 'no-cache' );
        $res->header( 'Cache-Control' => 'no-cache' );

        # set test session cookie
        if ($path eq 'index' || $path =~ /\.t$/) {
            $res->cookies->{$jstapd_prefix} = { value => $session };
        }
    } elsif (($path) = $req->uri->path =~ m!^/${jstapd_prefix}__api/(.+)?$!) {
        # ajax request for jstapd
        $res = $self->api_handler($path, $req, $session);
        $res ||= HTTP::Engine::Response->new( status => 200, body => '{msg:"ok"}' );

    } elsif ($apiurl && $req->uri->path =~ /$apiurl/) {
        # ajax request for appication
        $session = $req->cookie($jstapd_prefix)->value;
        my $current_path = $self->get_session($session)->{current_path};
        $res = JSTAPd::Server::Contents->handler("contents/$current_path", $self, $req, $session, { path => $current_path, is_api => 1 });

        # push request
        my $param = $req->params;
        push @{ $self->{ajax_request_stack} }, +{
            method => $req->method,
            path   => $req->uri->path,
            query  => $req->uri->query,
            param  => $param,
        };

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
        if ($self->run_once) {
            # for prove -vl jstap/foor/01_test.t
            # or prove -vlr jstap
            $next_current = $self->get_session($session)->{current_path} = $self->{run_file}.'' unless $current_path;
            return $self->json_response(+{
                session => $session,
                path    => $next_current,
            });
        }

        my $is_next = $current_path ? 0 : 1;
        my $is_last = 0;
        $self->{contents}->visitor(sub{
            return if $is_last;
            my $args = shift;
            return if $args->{is_dir};
            return unless $args->{name} =~ /\.t$/;
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
    } elsif ($type eq 'pop_tap_request') {
        my $stack = $self->{ajax_request_stack} || +[];
        if (my $requests = $req->param('requests')) {
            if (scalar(@{ $stack }) >= $requests) {
                $stack = [ splice @{ $stack }, 0, $requests ];
            } else {
                $stack = +[];
            }
        } else {
            $self->{ajax_request_stack} = +[];
        }
        return $self->json_response($stack);

    } elsif ($type eq 'exit') {
        return unless $self->run_once && ref($self->{destroy}) eq 'CODE';
        my $tap = $self->get_tap($session, $current_path);
        $self->{destroy}->($self->{stdout}, $tap);
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
    my $res;
    eval {
        $res = HTTP::Engine::Response->new( body => JSON::XS->new->ascii->encode($_[1]) );
    };
    if ($@) {
        warn Dumper($_[1]);
        warn $@;
    }
    $res;
}

1;
