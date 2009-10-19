package JSTAPd::TAP;
use strict;
use warnings;

sub new {
    my $class = shift;
    bless {
        tests => undef,
        tap   => [],
    }, $class;
}

sub tests { $_[0]->{tests} = defined $_[1] ? $_[1] : $_[0]->{tests} }
sub error { $_[0]->{error} = defined $_[1] ? $_[1] : $_[0]->{error} }

sub push_tap {
    my($self, $tap) = @_;
    push @{ $self->{tap} }, $tap;
}

sub each_tap {
    my($self, $cb) = @_;

    for my $tap (@{ $self->{tap} }) {
        $cb->($tap);
    }
}

sub as_string {
    my $self = shift;
    my $str;

    $str = sprintf "1..%d\n", $self->tests if $self->tests;
    $self->each_tap(sub {
        my $tap = shift;
        $str .= sprintf "%s %d%s\n", $tap->{ret}, $tap->{num}, ($tap->{msg} ? ' - ' . $tap->{msg} : '');
        $str .= "# $tap->{comment}\n" if $tap->{comment};
        unless ($tap->{ret} eq 'ok') {
            $str .= sprintf <<"MSG", ($tap->{msg} || $tap->{num}), $tap->{got}, $tap->{expected},
#   Failed test '%s'
#          got: '%s'
#     expected: '%s'
MSG
        }
    });
    $str .= $self->error . "\n" if $self->error;

    return $str;
}

sub as_hash {
    my $self = shift;
    my $hash = +{
        tests => $self->tests || 0,
        run   => 0,
        ok    => 0,
        fail  => 0,
        error => $self->error,
    };

    $self->each_tap(sub {
        my $tap = shift;
        $hash->{run}++;
        if ($tap->{ret} eq 'ok') {
            $hash->{ok}++;
        } else {
            $hash->{fail}++;
        }
    });
    $hash;
}

1;

