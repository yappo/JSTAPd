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
        <div id="results" style="border: 1px solid red; margin: 10px"></div>
        <input type="button" id="make-test" value="make test"/>
    </body>
</html>
HTML
}

sub _default_tap_lib {
    my $js =<<'JS';
// tap lib

// queue
var queue = [];
var is_xhr_running = 0;
var in_dequeueing  = false;
var dequeue = function(){
    if (_is_dequeueing()) return;
    in_dequeueing = true;
    var cb = queue.shift();
    if (cb && typeof cb == 'function') cb();
    in_dequeueing = false;
};
var enqueue = function(cb){
    queue.push(cb);
    dequeue();
};
var _is_dequeueing = function(){ return is_xhr_running || in_dequeueing };
var is_dequeueing  = function(){ return _is_dequeueing() || queue.length };

// ajax base
var xhr = function(){
    return window.ActiveXObject ? new ActiveXObject("Microsoft.XMLHTTP") : new XMLHttpRequest();
};
var get = function(prefix, query, cb){
    var r = xhr();
    var uri = jstapd_prefix + prefix + '?_='+(new Date).getTime();
    query.session = session;
    query.path    = path;
    var query_stack = [uri];
    for (k in query) {
        query_stack.push(encodeURIComponent(k) + '=' + encodeURIComponent(query[k]));
    }

    r.open('GET', query_stack.join('&'));
    r.onreadystatechange = function() {
        if (r.readyState == 4 && r.status == 200) {
            if (cb && typeof cb == 'function') cb(r);
            is_xhr_running--;
            dequeue();
        }
    }
    is_xhr_running++;
    r.send(null);
};
var tap = function(type, query, cb){
    query.type = type;
    get('tap', query, cb);
};

// util
window.tap$ = function(id){
    return document.getElementById(id);
};
window.tap$tag = function(tag){
    return document.getElementsByTagName(tag)[0];
};
JS

    return $js.__jstapdeferred_lib();
}

sub __jstapdeferred_lib {
    return <<'JS';
var id = 1;
window.jstapDeferred = function(){
    this.id = id++;
}

jstapDeferred.prototype = {
    cb: function(v){ return v },
    dnext: null,
    error: null,
    nextval: null,
    retry: function(count, cb){
        if (this.error) return;
        var ret = cb();
    },
    next: function(cb, m){
        this.dnext = new jstapDeferred();
        this.dnext.cb = cb;
        return this.dnext;
    },
    call: function(nextval){
        if (this.error) return;
        var retval;
        try {
            if (this.nextval !== null) nextval = this.nextval;
            retval = this.cb.call(this, nextval);
        } catch (e) {
            this.error = e;
        }
        if (retval instanceof jstapDeferred) {
            retval.dnext = this.dnext;
            if (retval.dnext !== null) retval.dnext.nextval = nextval;
        } else {
            if (this.dnext) this.dnext.call(retval);
        }
    },
    nop: function(r){ return r }
};
jstapDeferred.next = function(f){
    var d = new jstapDeferred;
    if (f) d.cb = f;
    setTimeout(function(){ d.call() }, 0);
    return d;
};

jstapDeferred.wait = function(t){
    var d = new jstapDeferred;
    setTimeout(function(){ d.call() }, t);
    return d;
};

jstapDeferred.retry = function(c,f,o){
    if (!o) o = {};
    var t = o.wait || 0;
    var d = new jstapDeferred;
    var val;
    var retry = function(){
        if (d.dnext.nextval !== null) val = d.dnext.nextval;
        d.dnext.nextval = null;
        var ret = f(c, val);
        if (ret) {
            d.dnext.call(ret);
        } else if (--c <= 0) {
            d.error = 'retry failed';
        } else {
            setTimeout(retry, t);
        }
    };
    setTimeout(retry, 0);
    return d;
};


jstapDeferred.xhr = function(o){
    if (!o) o = {};

    var url = o.url;
    if (!url) throw 'url missing';
    if (o.cache === false) {
        var c = '_='+(new Date).getTime()
        if (url.match(/\?/)) {
            url += '&'+c;
        } else {
            url += '?'+c;
        }
    }

    var r = xhr();
    r.open(o.method, url);
    var d = new jstapDeferred;
    r.onreadystatechange = function() {
        if (r.readyState != 4) return;
        d.call(r);
        return null;
    };
    r.send(null);
    return d;
};

jstapDeferred.pop_request = function(o){
    if (!o) o = {};
    var retry = o.retry;
    var wait  = o.wait || 0;
    var opts  = {};
    if (o.requests) opts.requests = o.requests;

    var d = new jstapDeferred;
    var func = function(req){
        d.dnext.nextval = req; // replace next value
        d.call(req);
        return null;
    };

    if (retry) {
        var f = function(){
            pop_tap_request(function(req){
                if (req.length || --retry <= 0) {
                    return func(req);
                } else {
                    // retry
                    setTimeout(f, wait);
                }
            }, opts);
        };
        setTimeout(f, 0);
    } else {
        pop_tap_request(func, opts);
    }
    return d;
};

jstapDeferred.register = function(n, f){
    this.prototype[n] = function(){
        var a = arguments;
        return this.next(function (v) {
            return f.apply(this, a);
        });
    };
};

jstapDeferred.register('wait', jstapDeferred.wait);
jstapDeferred.register('retry', jstapDeferred.retry);
jstapDeferred.register('xhr', jstapDeferred.xhr);
jstapDeferred.register('pop_request', jstapDeferred.pop_request);

JS
}

1;

__END__

=head1 NAME

JSTAPd::Contents - test file manager

=cut

