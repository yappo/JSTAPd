package JSTAPd::ContentsBag;
use strict;
use warnings;

use JSTAPd::Contents;

sub dir { $_[0]->{dir} }

sub new {
    my($class, %args) = @_;

    my $self = bless { dir => $args{dir}, run_file => $args{run_file} }, $class;
    $self;
}

sub _loader {
    my($self, $base) = @_;

    my $dir = +{ children => +{}, map => +{}, path => $base };
    my @contents;
    for my $path ($base->children) {
        if ($path->is_dir) {
            my $name  = $path->dir_list(-1);
            my $stuff = $self->_loader($path);
            $stuff->{name} = $name;
            push @contents, $stuff;
            $dir->{children}->{$name} = $stuff;
            next;
        }
        my $basename = $path->basename;
        next unless $path =~ /\.t$/ || $basename eq 'index';
        if ($self->{run_file} && $basename ne 'index') {
            next unless $path->relative($self->{dir}) eq $self->{run_file};
        }
        my $stuff = JSTAPd::Contents->new( $basename => $path );
        push @contents, $stuff;
        $dir->{map}->{$basename} = $stuff;
    }
    $dir->{contents} = \@contents;
    $dir;
}

sub load {
    my $self = shift;
    $self->{contents} = $self->_loader( $self->{dir} );
}

sub fetch_file {
    my($self, $basename, $chain, $is_inherit) = @_;

    my $dir = $self->{contents};
    my $parent = $dir->{map}->{$basename};
    for my $name (@{ $chain || [] }) {
        unless ($dir = $dir->{children}->{$name}) {
            return;
        }
        $parent = $dir->{map}->{$basename} || $parent;;
    }
    my $content = $dir->{map}->{$basename};
    $content = $parent if !$content && $is_inherit;
    return $content;
}

sub fetch_dir {
    my($self, $chain) = @_;

    my $dir = $self->{contents};
    for my $name (@{ $chain || [] }) {
        unless ($dir = $dir->{children}->{$name}) {
            return;
        }
    }
    return $dir;
}

sub each {
    my($self, $chain, $cb) = @_;
    my $dir   = $self->fetch_dir($chain);
    for my $contents (@{ $dir->{contents} }) {
        my $is_dir = ref($contents) eq 'HASH';
        $cb->($contents->{name}, $is_dir);
    }
}

sub _visitor {
    my($self, $path, $contents, $cb) = @_;
    for my $child (@{ $contents }) {
        my $current = $path;
        $current .= '/' if $current;
        $current .= $child->{name};
        my $is_dir = (ref($child) eq 'HASH');
        $cb->({
            name   => $child->{name},
            path   => $current,
            is_dir => $is_dir,
            child  => $child,
        });
        $self->_visitor($current, $child->{contents}, $cb) if $is_dir;
    }
}

sub visitor {
    my($self, $cb) = @_;
    $self->_visitor('', $self->{contents}->{contents}, $cb);
}

sub test_plans {
    my $self = shift;
    my $files = 0;
    my $tests = 0;
    $self->visitor(sub {
        my $obj   = shift;
        my $child = $obj->{child};
        return unless ref $child eq 'JSTAPd::Contents';
        next unless $child->can('suite');
        my $suite = $child->suite;
        return unless $suite;

        $files++;
        $tests += $suite->tests;
    });
    +{
        files => $files,
        tests => $tests,
    };
}

1;
