use JSTAPd::Suite;
__DATA__
__SCRIPT__
tests(6);
ok(1, 'ok 1');
ok(!0, 'ok 0');
is('test', 'test', 'is');
isnt('test', 'dev', 'isnt');
like('test', new RegExp('es'), 'like');
is(tap$('test').innerHTML, 'DATA', 'getElementById');
__HTML__
<div id='test'>DATA</div>
