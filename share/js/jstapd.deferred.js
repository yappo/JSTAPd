(function(){
var id = 1;
window.jstapDeferred = function(){
	this.id = id++;
}

jstapDeferred.prototype = {
	cb: function(v){ return v },
	dnext: null,
	error: null,
	nextval: null,
	retry: function(count, cb){
		if (this.error) return;
		var ret = cb();
	},
	next: function(cb, m){
		this.dnext = new jstapDeferred();
		this.dnext.cb = cb;
window.console.log("SET id: " + this.id);
window.console.log("SET: " + cb);
		return this.dnext;
	},
	call: function(nextval){
		if (this.error) return;
//if (window.yappo) {
window.console.log("おうっふ");
//}
		var retval;
window.console.log("-RET id: " + this.id);
window.console.log("-RET0: " + this.error);
window.console.log("-RET1: " + retval);
window.console.log("-RET2: " + this.dnext);
if (this.dnext) window.console.log("-RET: " + this.dnext.cb);
		try {
			if (this.nextval !== null) nextval = this.nextval;
			retval = this.cb.call(this, nextval);
		} catch (e) {
			this.error = e;
		}
window.console.log("+RET id: " + this.id);
window.console.log("+RET0: " + this.error);
window.console.log("+RET1: " + retval);
window.console.log("+RET2: " + this.dnext);
if (this.dnext) window.console.log("+RET: " + this.dnext.cb);
		if (retval instanceof jstapDeferred) {
			retval.dnext = this.dnext;
			if (retval.dnext !== null) retval.dnext.nextval = nextval;
		} else {
			if (this.dnext) this.dnext.call(retval);
		}
	},
	nop: function(r){ return r }
};
jstapDeferred.next = function(f){
    var d = new jstapDeferred;
    if (f) d.cb = f;
    setTimeout(function(){ d.call() }, 0);
    return d;
};

jstapDeferred.wait = function(t){
    var d = new jstapDeferred;
    setTimeout(function(){ d.call() }, t);
    return d;
};

jstapDeferred.retry = function(c,f,o){
    if (!o) o = {};
    var t = o.wait || 0;
    var d = new jstapDeferred;
    var val;
    var retry = function(){
        if (d.dnext.nextval !== null) val = d.dnext.nextval;
        d.dnext.nextval = null;
        var ret = f(c, val);
        if (ret) {
            d.dnext.call(ret);
        } else if (--c <= 0) {
            d.error = 'retry failed';
        } else {
            setTimeout(retry, t);
        }
    };
    setTimeout(retry, 0);
    return d;
};


jstapDeferred.xhr = function(o){
    if (!o) o = {};

    var url = o.url;
    if (!url) throw 'url missing';
    if (o.cache === false) {
        var c = '_='+(new Date).getTime()
        if (url.match(/\?/)) {
            url += '&'+c;
        } else {
            url += '?'+c;
        }
    }

    var r = JSTAPd.xhr();
    r.open(o.method, url);
    var d = new jstapDeferred;
    r.onreadystatechange = function() {
        if (r.readyState != 4) return;
        d.call(r);
        return null;
    };
    r.send(null);
    return d;
};

jstapDeferred.pop_request = function(o){
    if (!o) o = {};
    var retry = o.retry;
    var wait  = o.wait || 0;
    var opts  = {};
    if (o.requests) opts.requests = o.requests;

    var d = new jstapDeferred;
    var func = function(req){
        d.dnext.nextval = req; // replace next value
        d.call(req);
        return null;
    };

    if (retry) {
        var f = function(){
            pop_tap_request(function(req){
                if (req.length || --retry <= 0) {
                    return func(req);
                } else {
                    // retry
                    setTimeout(f, wait);
                }
            }, opts);
        };
        setTimeout(f, 0);
    } else {
        pop_tap_request(func, opts);
    }
    return d;
};

jstapDeferred.register = function(n, f){
    this.prototype[n] = function(){
        var a = arguments;
        return this.next(function (v) {
            return f.apply(this, a);
        });
    };
};

jstapDeferred.register('wait', jstapDeferred.wait);
jstapDeferred.register('retry', jstapDeferred.retry);
jstapDeferred.register('xhr', jstapDeferred.xhr);
jstapDeferred.register('pop_request', jstapDeferred.pop_request);

// for *.t file
// load js libs
jstapDeferred.register('include', function(src){
	var d = new jstapDeferred;
	var script = document.createElement('script');
	var onload = function(){ d.call() };
	if (typeof(script.onreadystatechange) == 'object') {
		script.onreadystatechange = function(){
			if (script.readyState != 'loaded' && script.readyState != 'complete') return;
			onload();
		};
	} else {
		tap_addevent(script, 'load', onload);
	}
	script.src = src;
	tap$tag('body').appendChild(script);
	return d;
});

// waiting testing done
jstapDeferred.register('wait_finish', function(){
	var d = new jstapDeferred;
window.console.log("start: あばばばば" + JSTAPd.tap_count + ', ' + JSTAPd.tap_tests);
	if (JSTAPd.tap_tests == 0) {
		d.call();
	} else {
		// async done mode
		var do_async = function(){
window.console.log("あばばばば" + JSTAPd.tap_count + ', ' + JSTAPd.tap_tests);
			if (JSTAPd.tap_count >= JSTAPd.tap_tests) {
				d.call();
			} else {
				setTimeout(do_async, 10);
			}
		};
		setTimeout(do_async, 10);
	}
	return d;
});

// wait dequeueing
jstapDeferred.wait_dequeue = function(cb){ // cb is for test
	var d = new jstapDeferred;
	var wait = function(){
		if (JSTAPd.is_dequeueing()) {
			if (cb && typeof(cb) == 'function') cb(false);
			setTimeout(wait, 100);
		} else {
			if (cb && typeof(cb) == 'function') cb(true);
			d.call();
		}
	};
	setTimeout(wait, 0);
	return d;
};
jstapDeferred.register('wait_dequeue', jstapDeferred.wait_dequeue);
})();
