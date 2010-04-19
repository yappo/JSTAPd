use JSTAPd::Suite;

sub tests { 7 }

sub client_script {
    return <<'DONE';
var w1 = 0, w2 = 0;
var w1_falsed = false;
var w2_falsed = false;
return jstapDeferred.next(function(){
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
}).
wait_dequeue(function(b){
    if (b === true) {
        if (w1 >= 1) {
            ok(1, 'dequeue 1-1 ok');
        } else {
            ok(0, 'dequeue 1-1 ng');
        }
    } else {
        if (w1 == 0) {
            ok(1, 'dequeue 1-2 ok');
            w1_falsed = true;
        } else if (!w1_falsed)  {
            ok(0, 'dequeue 1-2 ng');
        }
    }
    w1++;
}).
next(function(){
    ok(1, 1);
    ok(1, 2);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
    tests(7);
}).
wait_dequeue(function(b){
    if (b === true) {
        if (w2 >=1) {
            ok(1, 'dequeue 2-1 ok');
        } else {
            ok(0, 'dequeue 2-1 ng');
        }
    } else {
        if (w2 == 0) {
            ok(1, 'dequeue 2-2 ok');
            w2_falsed = true;
        } else if(!w2_falsed) {
            ok(0, 'dequeue 2-2 ng');
        }
    }
    w2++;
}).
next(function(){
    ok(1, 3);
});

DONE
}
