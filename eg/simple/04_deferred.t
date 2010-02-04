use JSTAPd::Suite;

sub client_script {
    return <<'DONE';
tests(27);
var c = 0;
// next
jstapDeferred.next(function(){
c = 0;
return jstapDeferred.next(function(){
    is(c++, 0, 'count');
    return 'next1';
}).
next(function(val){
    is(c++, 1, 'count');
    is(val, 'next1', '1 next1');
    return 'next2';
}).
next(function(val){
    is(c++, 2, 'count');
    is(val, 'next2', '1 next2');
});
}).

// wait
next(function(){
c = 0;
var t = new Date();
return jstapDeferred.wait(100).next(function(v){ // 1, 2
    is(c++, 0, 'wait count 0');
    var el = (new Date).getTime() - t.getTime();
    is((el < 190 && el > 9), true, 'wait elapsed');
    return 'next1';
}).next(function(val){ // 3
    is(c++, 1, 'wait count 1');
    is(val, 'next1', 'wait next 1');
    t = new Date();
    return 'next2';
}).
wait(200).next(function(val,x){ // 4(7), 5 
    is(c++, 2, 'wait count 2');
    var el = (new Date).getTime() - t.getTime();
    is((el < 310 && el > 90), true, 'wait elapsed 2');
    is(val, 'next2', 'wait next 2');
    return 'next3';
}).next(function(val){ // 6
    is(c++, 3, 'wait count 3');
    is(val, 'next3', 'wait next 3');
});
}).

// retry
next(function(){
c = 0;
return jstapDeferred.retry(3, function(count, val){
    is(c++, (0+3-count), 'retry count 1');
    if (count != 1) return;
    return 'retry1';
}).
next(function(val){
    is(c++, 3, 'count 2');
    is(val, 'retry1', 'retry next 1');
    return 'next1';
}).
retry(4, function(count, val){
    is(c++, (4+4-count), 'retry count 3');
    is(val, 'next1', 'retry retry 1');
    if (count != 2) return;
    return 'retry2';
}).
next(function(val){
    is(c++, 7, 'count 4');
    is(val, 'retry2', 'retry next 2');
});

});
DONE
}
