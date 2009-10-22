use JSTAPd::Suite;

sub client_script {
    return <<'DONE';
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
