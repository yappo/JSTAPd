package JSTAPd::Server;
use strict;
use warnings;
use AE;
use Data::Dumper;
use File::ShareDir;
use File::Spec;
use JSON::XS;
use HTTP::Request;
use LWP::UserAgent;
use Path::Class;
use Time::HiRes;

use Plack::App::Directory;
use Plack::Builder;
use Plack::Request;
use Plack::Response;
use Plack::Runner;

use JSTAPd;
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

    $hash->{auto_open_command} = $ENV{JSTAP_AUTO_OPEN_COMMAND} if $ENV{JSTAP_AUTO_OPEN_COMMAND};

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

    my $env = 'development';
    $env = 'jstapd_auto_open' if $self->auto_open;
    my $runner = Plack::Runner->new(
        env     => $env,
        server  => 'Twiggy',
        options => [
            host => $self->{host},
            port => $self->{port},
        ],
    );
    print STDERR "starting: $uri\n" unless $self->auto_open;

    my $contents_htroot = sprintf '/%s/contents', $self->jstapd_prefix;
    my $share_htroot = sprintf '/%s/share', $self->jstapd_prefix;
    my $share_root   = eval { File::ShareDir::dist_dir('JSTAPd') } || do {
        my @dirs = File::Spec->splitdir($INC{'JSTAPd.pm'});
        pop @dirs; pop @dirs;
        File::Spec->catfile(@dirs, 'share');
    };

    my $jstapd_app   = $self->psgi_app;
    my $contents_dir = Plack::App::Directory->new( root => $self->{dir} )->to_app;
    my $contents_app = sub {
        my $path_info = $_[0]->{PATH_INFO};
        return $contents_dir->(@_) unless $path_info =~ /\.t\z/;
        $jstapd_app->(@_);
    };

    my $app = builder {
        mount "$share_htroot"    => Plack::App::Directory->new( root => $share_root )->to_app;
        mount "$contents_htroot" => $contents_app,
        mount "/"                => $jstapd_app;
    };
    $runner->run( $app->to_app );
}

sub psgi_app {
    my $self = shift;
    return sub {
        my $res = $self->handler(@_);
        return $res unless ref $res eq 'Plack::Response';
        return $res->finalize();
    };
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
    my($self, $env) = @_;

    my $req = Plack::Request->new($env);

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
            $res->cookies->{$jstapd_prefix} = {
                value => $session,
                path  => '/',
            };
        }
    } elsif (($path) = $req->uri->path =~ m!^/${jstapd_prefix}__api/(.+)?$!) {
        # ajax request for jstapd
        $res = $self->api_handler($path, $req, $session);
        $res ||= Plack::Response->new( 200, [ 'Content-Type' => 'application/json' ], '{msg:"ok"}' );

    } elsif ($apiurl && $req->uri->path =~ /$apiurl/) {
        # ajax request for appication
        $session = $req->cookies->{$jstapd_prefix};
        my $current_path = $self->get_session($session)->{current_path};
        $res = JSTAPd::Server::Contents->handler("contents/$current_path", $self, $req, $session, { path => $current_path, is_api => 1 });

        # push request
        my $param = $req->parameters->as_hashref_mixed;
        my $current = $self->get_path($session, $current_path);
        push @{ $current->{ajax_request_stack} }, +{
            method => $req->method,
            path   => $req->uri->path,
            query  => $req->uri->query,
            param  => $param,
        };
        if ($current->{pop_tap_request}) {
            # send waiting request
            my $stack = $current->{ajax_request_stack} || +[];
            $stack = [ splice @{ $stack }, 0, $current->{pop_tap_request}->{requests} ];
            $current->{pop_tap_request}->{cv}->send(
                $self->json_response($stack)
            );
        }
    } else {
        # ajax request?
        my $path = $self->decode_urlmap($req->uri->path);
        # XXX Content-Type?
        $res = Plack::Response->new( 200, [], $self->{dir}->file($path)->slurp.'' );
    }

    return $res || Plack::Response->new( 404, [ 'Content-Type' => 'text/plain' ], 'Not Found' );
}

sub api_handler {
    my($self, $type, $req, $session) = @_;

    # for main index
    my $current_path = $self->get_session($session)->{current_path};
    if (my $code = JSTAPd::Server::controller->can($type)) {
        my $ret = $code->($self, $session, $req, $current_path);
        return $ret if $ret;
    }

    # for tap test
    my $path = $req->param('path');
    my @session_path = ($session, $path);

    my $tap = $self->get_tap(@session_path);
    my $current = $self->get_path(@session_path);
    if ($type eq 'tests') {
        $tap->tests($req->param('num'));
    } elsif ($type eq 'tap') {
        $tap->push_tap($req->parameters);
    } elsif ($type eq 'tap_done') {
        if (my $error = $req->param('error')) {
            $tap->error($error);
        }
        if ($current->{end_cv}) {
            $current->{end_cv}->send();
        }
        $self->get_path(@session_path)->{is_end} = 1;
        return Plack::Response->new( 200, [ 'Content-Type' => 'text/plain' ], $tap->as_string );
    } elsif ($type eq 'dump') {
        warn Dumper($tap);
    }
    return;
}

sub json_response {
    my $res;
    eval {
        $res = Plack::Response->new( 200, ['Content-Type' => 'application/json' ], JSON::XS->new->ascii->encode($_[1]) );
    };
    if ($@) {
        warn Dumper($_[1]);
        warn $@;
    }
    $res;
}

package JSTAPd::Server::controller;

sub get_next {
    my($c, $session, $req, $current_path) = @_;
    my $next_path = -1;
    if ($c->run_once) {
        # for prove -vl jstap/foor/01_test.t
        # or prove -vlr jstap
        $next_path = $c->get_session($session)->{current_path} = $c->{run_file}.'' unless $current_path;
        return $c->json_response(+{
            session => $session,
            path    => $next_path,
        });
    }

    my $is_next = $current_path ? 0 : 1;
    my $is_last = 0;
    $c->{contents}->visitor(sub{
        return if $is_last;
        my $args = shift;
        return if $args->{is_dir};
        return unless $args->{name} =~ /\.t$/;
        if ($is_next) {
            $next_path = $args->{path};
            $is_last++;
            return;
        }
        if ($current_path eq $args->{path}) {
            $is_next++;
        }
    });
    $c->get_session($session)->{current_path} = $current_path = $next_path;
    return $c->json_response(+{
        session => $session,
        path    => "$current_path",
    });
}

sub watch_finish {
    my($c, $session, $req, $current_path) = @_;

    my @session_path = ($session, $current_path);
    my $current = $c->get_path(@session_path);
    if ($current_path && $current) {
        # 終了までまってるなり
        if ($current->{is_end}) {
            # もうおわってた
            my $tap = $c->get_tap(@session_path);
            return $c->json_response({
                session => $session,
                path    => $current_path,
                tap     => $tap->as_hash,
            });
        } elsif ($current->{end_cv}) {
        } else {
            $current->{end_cv} = AE::cv;
            return sub {
                my $start_response = shift;
                $current->{end_cv}->cb(
                    sub {
                        shift->recv;
                        my $tap = $c->get_tap(@session_path);
                        $start_response->( $c->json_response({
                            session => $session,
                            path    => $current_path,
                            tap     => $tap->as_hash,
                        })->finalize );
                    }
                );
            }
        }
    }
}

sub pop_tap_request {
    my($c, $session, $req, $current_path) = @_;

    my $current = $c->get_path($session, $current_path);
    my $stack = $current->{ajax_request_stack} || +[];
    if (my $requests = $req->param('requests')) {
        if (scalar(@{ $stack }) >= $requests) {
            $stack = [ splice @{ $stack }, 0, $requests ];
        } else {
            # waiting
            if ($current->{pop_tap_request}) {
                # XXX error handling
                return Plack::Response->new( 500, [ 'Content-Type' => 'text/plain' ], 'over fllow pop_tap_request request' );
            }
            $current->{pop_tap_request} = {
                cv       => AE::cv,
                requests => $requests,
            };
            return sub {
                my $start_response = shift;
                $current->{pop_tap_request}->{cv}->cb(
                    sub {
                        my $tmp = delete $current->{pop_tap_request};
                        $start_response->( shift->recv->finalize );
                    }
                );
            }
        }
    } else {
        $current->{ajax_request_stack} = +[];
    }
    return $c->json_response($stack);
}

sub exit {
    my($c, $session, $req, $current_path) = @_;
    return unless $c->run_once && ref($c->{destroy}) eq 'CODE';
    my $tap = $c->get_tap($session, $current_path);
    $c->{destroy}->($c->{stdout}, $tap);
}

package JSTAPd::Server;
1;
