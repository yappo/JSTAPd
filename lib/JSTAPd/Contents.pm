package JSTAPd::Contents;
use strict;
use warnings;
use FindBin;

sub suite { $_[0]->{suite} }

sub new {
    my($class, $name, $path) = @_;

    my $self = bless {
        name  => $name,
        path  => $path,
        suite => undef,
    }, $class;
    $self->parse if $path =~ /\.t$/;
    $self;
}

sub slurp { $_[0]->{slurp} ||= $_[0]->{path}->slurp }

my $ANON_CLASS_COUNT = 0;

sub parse {
    my $self = shift;

    my $script = $self->slurp;
    my $package = join '::', __PACKAGE__, 'AnonClass', 'Num'.($ANON_CLASS_COUNT++);
    my $code = "
# line 1 $package.pm
package $package; ## 
BEGIN{ \$$package\::IN_THE_PARSE = 1 };
# line 1 $self->{path}
$script;
# line 5 $package.pm
sub path { '$self->{path}' }
sub name { '$self->{name}' }
JSTAPd::Suite::export(__PACKAGE__);
1;";
    do {
        local $FindBin::Bin = $self->{path}->dir;
        eval $code; ## no critic
    };
    $@ and die $@;
    $self->{suite} = $package->new;
}

sub header {
    my($self, %args) = @_;
    my $script = $self->suite->client_script;

    return sprintf <<'HTML', $args{jstapd_prefix}, $args{jstapd_prefix}, $args{jstapd_prefix}, $args{session}, $args{path}, ($args{include} || 'nop()'), $script;
<script type="text/javascript" src="/%s/share/js/jstapd.js"></script>
<script type="text/javascript" src="/%s/share/js/jstapd.deferred.js"></script>
<script type="text/javascript">
(function(){
JSTAPd.jstapd_prefix = '/%s__api/';
JSTAPd.session       = '%s';
JSTAPd.path          = '%s';

window.onload = function(){
    jstapDeferred.next(function(){
        // lib load
        return jstapDeferred.next(function(){}).
%s
        ;
    }).
    next(function(){
        // run test
%s
    }).
    wait_finish().
    next(function(){
        // done
        tap_done('');
    });
}
})();
</script>
HTML
}

sub build_html {
    my($self, $head, $body) = @_;
    my $index = $self->slurp;
    $body = sprintf '<div id="jstap_users_body_container">%s</div>', $body;
    $index =~ s/\$HEAD/$head/g;
    $index =~ s{\$BODY}{$body<div id="jstap_tap_result_container"></div>}g;
    $index;
}

sub build_index {
    my($class, %args) = @_;
    _default_index(%args);
}

sub _default_index {
    my %args = @_;

    return sprintf <<'HTML', $args{jstapd_prefix}, $args{jstapd_prefix}, $args{jstapd_prefix}, $args{jstapd_prefix}, ($args{run_once} ? 'true' : 'false'), ($args{auto_open} ? 'true' : 'false');
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <meta http-equiv="content-script-type" content="text/javascript">
        <title>JSTAPd main index</title>
<script type="text/javascript" src="/%s/share/js/jstapd.js"></script>
<script type="text/javascript" src="/%s/share/js/jstapd.index.js"></script>
<script type="text/javascript">
JSTAPd.jstapd_prefix = '/%s__api/';
JSTAPd.contents_prefix = '/%s/contents/';
JSTAPd.session = '';
JSTAPd.path = '';
JSTAPd.run_once = %s;
JSTAPd.auto_open = %s;
</script>
    </head>
    <body id="body">
        <div>Test Files: <span id="test_files"></span></div>
        <div>Test Plans: <span id="test_plans"></span></div>
        <div id="results" style="border: 1px solid red; margin: 10px"></div>
        <input type="button" id="make-test" value="make test"/>
    </body>
</html>
HTML
}

1;

__END__

=head1 NAME

JSTAPd::Contents - test file manager

=cut

