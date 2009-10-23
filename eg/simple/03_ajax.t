use JSTAPd::Suite;

sub client_script {
    return <<'DONE';
tests(17);
setTimeout(function(){ ok(1, 'timeout'); }, 200);

var i = 0;
var get = 0;
function run_test1(){
    var xhr = tap_xhr();
    var now = ++i;
    xhr.open('GET', '/api/get?key=value&i='+now);
    xhr.onreadystatechange = function() {
        if (xhr.readyState != 4) return;
        is(xhr.status, 200, 'GET STATUS CODE');
        is(xhr.responseText, 'response body '+now+' - '+now, 'GET RESPONSE BODY '+now);
        get++;
    };
    xhr.send(null);
}

run_test1();
var run_test2; run_test2 = function(){
    if (i) {
        run_test1();
    } else {
        setTimeout(run_test2, 100);
    }
};
setTimeout(run_test2, 100);

var run_test3; run_test3 = function(){
    if (get != 2) {
        setTimeout(run_test3, 100);
        return;
    }

    // check request data from server
    pop_tap_request(function(req){
        is(req.length, 2, '2 requests')
        is(req[0].method, 'GET'          , 'method 1')
        is(req[0].path  , '/api/get'     , 'path 1')
        is(req[0].query , 'key=value&i=1', 'query 1')
        is(req[0].param.key , 'value', 'param.key 1')
        is(req[0].param.i   , '1'    , 'param.i 1')

        is(req[1].method, 'GET'          , 'method 2')
        is(req[1].path  , '/api/get'     , 'path 2')
        is(req[1].query , 'key=value&i=2', 'query 2')
        is(req[1].param.key , 'value', 'param.key 2')
        is(req[1].param.i   , '2'    , 'param.i 2')

        pop_tap_request(function(req){
            is(req.length, 0, 'empty request');
        });
    });
};
setTimeout(run_test3, 100);
DONE
}

sub server_api {
    my($self, $global, $req, $method, $path) = @_;
    $global->{i} ||= 0;

    if ($path eq '/api/get' && $method eq 'GET') {
        $global->{i}++;
        return "response body " . $global->{i} . " - " . $req->param('i');
    }
}
