use JSTAPd::Suite;
__DATA__
__SCRIPT__
tests(5);
setTimeout(function(){ ok(1, 'timeout'); }, 200);

var i = 0;
function run_test1(){
    var xhr = tap_xhr();
    var now = ++i;
    xhr.open('GET', '/api/get?key=value&i='+now);
    xhr.onreadystatechange = function() {
        if (xhr.readyState != 4) return;
        is(xhr.status, 200, 'GET STATUS CODE');
        is(xhr.responseText, 'response body '+now+' - '+now, 'GET RESPONSE BODY '+now);
    };
    xhr.send(null);
}

run_test1();
setTimeout(function(){ run_test1() }, 400);

__API__
$GLOBAL->{i} ||= 0;

if ($PATH eq '/api/get' && $METHOD eq 'GET') {
    $GLOBAL->{i}++;
    return "response body " . $GLOBAL->{i} . " - " . $PARAM->{i};
}
