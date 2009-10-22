package JSTAPd::Contents;
use strict;
use warnings;

sub new {
    my($class, $name, $path) = @_;

    my $self = bless {
        name => $name,
        path => $path,
    }, $class;
    $self->parse;
    $self;
}

sub slurp { $_[0]->{slurp} ||= $_[0]->{path}->slurp }

sub parse {
    my $self = shift;

    my @list;
    my @tmp;
    for my $line (split /\n/, $self->slurp) {
        if ($line =~ /^__(.+)__$/) {
            push @list, join("\n", @tmp) if @list;
            push @list, $1;
            @tmp = ();
            next;
        }
        push @tmp, $line;
    }
    push @list, join("\n", @tmp) if @list;

    $self->{list} = +{ @list };
    my @include = split /\n/, ($self->{list}->{INCLUDE} || '');
    $self->{include} = \@include;
    my @include_ext = split /\n/, ($self->{list}->{INCLUDE_EXT} || '');
    $self->{include_ext} = \@include_ext;
}

sub api { $_[0]->{list}->{API} || '' }

sub include { @{ $_[0]->{include} } }
sub html { $_[0]->{list}->{HTML} || '' }
sub script { $_[0]->{list}->{SCRIPT} || '' }

sub header {
    my($self, %args) = @_;
    my $script = $self->script;

    my $include = '';
    $include .= qq{<script src="$_" type="text/javascript"></script>} for (@{ $self->{include_ext} }, @{ $self->{include} });

    my $html = sprintf <<'HTML', $args{jstapd_prefix}, $args{session}, $args{path}, _default_tap_lib(), $args{pre_script}, $include, $script;
<script type="text/javascript">
(function(){
var jstapd_prefix = '/%s__api/';
var session       = '%s';
var path          = '%s';

%s

// test functions
var tap_count = 0;
var tap_tests = 0;
window.tests = function(num){
    tap_tests = num;
    enqueue(function(){
        get('tests', { num: num });
    });
};
window.ok   = function(val, msg){
    var ret;
    var comment = '';
    try {
        if (val) {
            ret = 'ok';
        } else {
            ret = 'not ok';
        }
    } catch(e) {
        comment = e;
    }

    enqueue(function(){
        tap('ok', {
            ret: ret,
            num: (++tap_count),
            msg: msg,
            comment: comment
        });
    });
};
window.is   = function(got, expected, msg){
    var ret;
    var comment = '';
    try {
        if (got == expected) {
            ret = 'ok';
        } else {
            ret = 'not ok';
        }
    } catch(e) {
        comment = e;
    }

    enqueue(function(){
        tap('is', {
            ret: ret,
            num: (++tap_count),
            msg: msg,
            got: got,
            expected: expected,
            comment: comment
        });
    });
};
window.isnt = function(got, expected, msg){
    var ret;
    var comment = '';
    try {
        if (got != expected) {
            ret = 'ok';
        } else {
            ret = 'not ok';
        }
    } catch(e) {
        comment = e;
    }

    enqueue(function(){
        tap('isnt', {
            ret: ret,
            num: (++tap_count),
            msg: msg,
            got: got,
            expected: expected,
            comment: comment
        });
    });
};
window.like = function(got, expected, msg){
    var ret;
    var comment = '';
    try {
        if (got.search(expected)) {
            ret = 'ok';
        } else {
            ret = 'not ok';
        }
    } catch(e) {
        comment = e;
    }

    enqueue(function(){
        tap('like', {
            ret: ret,
            num: (++tap_count),
            msg: msg,
            got: got,
            expected: expected.toString(),
            comment: comment
        });
    });
};

window.tap_done = function(error){
    var go_done = function(){
        enqueue(function(){
            get('tap_done', { error: error }, function(r){
                var div = document.createElement("div");
                div.innerHTML = r.responseText.replace(/\n/g, '<br>');
                tap$tag('body').appendChild(div);
                tap$('jstap_users_body_container').style.display = 'none';
            })
        });
    };
    if (tap_tests == 0) {
        go_done();
    } else {
        // async done mode
        var do_async; do_async = function(){
            if (tap_count >= tap_tests) {
                go_done();
            } else {
                setTimeout(do_async, 100);
            }
        };
        setTimeout(do_async, 100);
    }
};

window.tap_dump = function(){
    enqueue(function(){
        get('dump', {})
    });
};

window.tap_xhr = function(){
    return xhr();
};

window.include = function(src){
    enqueue(function(){
        var r = xhr();
        r.open('GET', src + '?_='+(new Date).getTime());
        r.onreadystatechange = function() {
            if (r.readyState != 4) return;
            if (r.status != 200) throw new Error(src + ' is not found');
            eval(r.responseText);
            is_xhr_running = false;
            dequeue();
        }
        is_xhr_running = true;
        r.send(null);
    });
};
})();
</script>
<script type="text/javascript">
(function(){
try {
%s
} catch(e) {
//    tap_done(e);
}
})();
</script>
%s
<script type="text/javascript">
(function(){
window.onload = function(){
try {
%s
    tap_done('');
} catch(e) {
    tap_done(e);
}
}
})();
</script>
HTML

}

sub body { $_[0]->html }

sub build_html {
    my($self, $head, $body) = @_;
    my $index = $self->slurp;
    $body = sprintf '<div id="jstap_users_body_container">%s</div>', $body;
    $index =~ s/\$HEAD/$head/g;
    $index =~ s/\$BODY/$body/g;
    $index;
}

sub build_index {
    my($class, %args) = @_;
    _default_index(%args);
}

sub _default_index {
    my %args = @_;

    return sprintf <<'HTML', $args{jstapd_prefix}, $args{jstapd_prefix}, _default_tap_lib();
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
    <head>
        <title>JSTAPd main index</title>
<script type="text/javascript">
var jstapd_prefix = '/%s__api/';
var contents_prefix = '/%s/contents/';
var session = '';
var path = '';

%s

(function(){

var status = {
    tests: []
};
var current_path = '';
function start_next(args){
    var body = tap$tag('body');

    var h = document.createElement("h2");
    var a = document.createElement("a");
    a.href = contents_prefix + args.path;
    a.target = '_blank';
    a.innerHTML = args.path;
    a.name = args.path;
    h.appendChild(a);
    body.appendChild(h);

    var iframe_div = document.createElement("div");
    body.appendChild(iframe_div);

    var iframe = document.createElement("iframe");
    iframe_div.appendChild(iframe);
    iframe.src = contents_prefix + path + '?session=' + session;
    iframe.width = '100%';

    var watch; watch = function(){
        get('watch_finish', {}, function(r){
            var json; eval('json = ' + r.responseText);
            if (json.status != 0 && json.session == session && json.path == path) {
                finish_and_next(json.tap, json.path, h);
            } else {
                setTimeout(watch, 200);
            }
        });
    };
    setTimeout(watch, 200);
}

function finish_and_next(json, name, h){
    var msg = ' .. ';
    var is_ok = 0;
    if (json.fail > 0) {
        msg += json.ok + '/' + json.run;
    } else if (json.error) {
        msg += json.ok + '/' + json.run + ' ' + json.error;
    } else {
        msg += 'ok';
        is_ok = 1;
    }
    if (json.tests > 0 && json.tests != json.run) {
        msg += ' # Looks like you planned ' + json.tests + ' test but ran ' + json.run + '.';
        is_ok = 0;
    }

    var span = document.createElement("span");
    span.innerHTML = msg;
    h.appendChild(span);

    status.tests.push({ name: name, msg: msg, is_ok: is_ok });
    get_next();
}

function all_tests_finish(){

    var ul = document.createElement("ul");

    var fails = 0;
    for (i in status.tests) {
        var ret = status.tests[i];
        var li = document.createElement("li");
        var a = document.createElement("a");
        a.href = '#' + ret.name;
        a.innerHTML = ret.name + ret.msg;
        li.appendChild(a);
        ul.appendChild(li);
        if (!ret.is_ok) fails++;
    }
    var results = tap$('results');
    results.appendChild(ul);

    var div1 = document.createElement("div");
    div1.innerHTML = 'Tests=' + status.tests.length + ', Fails=' + fails;
    results.appendChild(div1);
    
    var div2 = document.createElement("div");
    if (fails == 0) {
        div2.innerHTML = 'Result: PASS';
    } else {
        div2.innerHTML = 'Result: FAIL';
    }
    results.appendChild(div2);
}

function get_next(){
    get('get_next', {}, function(r){
        var json; eval('json = ' + r.responseText);
        if (!json.session) return;
        if (json.path == '-1') {
            all_tests_finish();
            return;
        }
        session = json.session;
        path    = json.path;
        start_next(json);
    });
}

window.onload = function(){
    tap$('make-test').onclick = function(){
        get_next();
    };
};
})();

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
    return <<'JS';
// tap lib

// queue
var queue = [];
var is_xhr_running = false;
var dequeue = function(){
    if (is_xhr_running) return;
    var cb = queue.shift();
    if (cb && typeof cb == 'function') cb();
};
var enqueue = function(cb){
    queue.push(cb);
    dequeue();
};

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
            is_xhr_running = false;
            dequeue();
        }
    }
    is_xhr_running = true;
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
}

1;

__END__

=head1 NAME

JSTAPd::Contents - test file manager

=cut

