use JSTAPd::Suite;

sub tests { 2 }

sub client_script {
    return <<'DONE';
is(include1('foo'), 'foo1', 'include1() in include1.js');
is(include2('bar'), 'bar2', 'include2() in include2.js');
DONE
}

sub include {
    qw(
          /jslib/include1.js
          /jslib/include2.js
    );
}
