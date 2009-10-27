use JSTAPd::Suite;

sub client_script {
    return <<'DONE';
tests(9);
var c = 0;

jstapDeferred.next(function(){
c = 0;
return jstapDeferred.xhr({
    method: 'GET',
    url:    '/xhr',
    cache:  false
}).
next(function(r){
    is(r.responseText, 'response body 1', 'xhr next 1');
}).
pop_request().
next(function(req){
    is(req.length, 1, 'pop_request 1 requests 1');
    is(req[0].path, '/xhr', 'pop_request 1 path');
}).
next(function(){
    setTimeout(function(){
    var xhr = tap_xhr();
    xhr.open('GET', '/xhr?_='+(new Date).getTime());
    xhr.onreadystatechange = function() {
        if (xhr.readyState != 4) return;
        is(xhr.status, 200, 'GET STATUS CODE');
        is(xhr.responseText, 'response body 2', 'GET RESPONSE BODY');
    };
    xhr.send(null);
    }, 500);
}).
pop_request().
next(function(req){
    is(req.length, 0, 'pop_request 0 requests 2');
}).
pop_request({ retry: 9, wait: 10 }).
next(function(req){
    is(req.length, 0, 'pop_request 0 requests 3');
}).
pop_request({ retry: 50, wait: 10 }).
next(function(req){
    is(req.length, 1, 'pop_request 1 requests 4');
    is(req[0].path, '/xhr', 'pop_request 1 path');
});

});
DONE
}

sub server_api {
    my($self, $global, $req, $method, $path) = @_;
    $global->{i} ||= 0;

    if ($path eq '/xhr' && $method eq 'GET') {
        $global->{i}++;
        return "response body " . $global->{i};
    }
}