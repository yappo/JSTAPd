use JSTAPd::Suite;
__DATA__
__SCRIPT__
tests(2);
is(include1('foo'), 'foo1', 'include1() in include1.js');
is(include2('bar'), 'bar2', 'include2() in include2.js');
__HTML__
<div id='test'>DATA</div>
__INCLUDE__
/jslib/include1.js
/jslib/include2.js
