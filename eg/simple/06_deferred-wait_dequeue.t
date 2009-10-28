use JSTAPd::Suite;

sub client_script {
    return <<'DONE';
var w1 = 0, w2 = 0;
return jstapDeferred.next(function(){
    tests(7);
}).
wait_dequeue(function(b){
    if (b === true) {
        if (w1 == 1) {
            ok(1, 'dequeue 1-1');
        } else {
            ok(0, 'dequeue 1-1');
        }
    } else {
        if (w1 == 0) {
            ok(1, 'dequeue 1-2');
        } else {
            ok(0, 'dequeue 1-2');
        }
    }
    w1++;
}).
next(function(){
    ok(1, 1);
    ok(1, 2);
}).
wait_dequeue(function(b){
    if (b === true) {
        if (w2 == 1) {
            ok(1, 'dequeue 2-1');
        } else {
            ok(0, 'dequeue 2-1');
        }
    } else {
        if (w2 == 0) {
            ok(1, 'dequeue 2-2');
        } else {
            ok(0, 'dequeue 2-2');
        }
    }
    w2++;
}).
next(function(){
    ok(1, 3);
});

DONE
}
