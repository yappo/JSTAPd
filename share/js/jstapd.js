if (typeof(JSTAPd) == 'undefined') JSTAPd = {
	jstapd_prefix: null,
	session      : null,
	path         : null,
	tap_count    : 0,
	tap_tests    : 0,
	xhr          : function(){},
	get          : function(){},
	is_dequeueing: function(){}
};

(function(){
// _default_tap_lib
// queue
var queue = [];
var is_xhr_running = 0;
var in_dequeueing  = false;
var queue_count = 1;
var dequeue = function(){
	if (_is_dequeueing()) return;
	in_dequeueing = true;
	var obj = queue.shift() || { id: 'null', cb: null };
	var cb = obj.cb;
	if (cb && typeof cb == 'function') cb();
	in_dequeueing = false;
};
var enqueue = function(cb){
	queue.push({
				   cb: cb,
				   id: queue_count++
			   });
	dequeue();
};
var _is_dequeueing = function(){ return is_xhr_running || in_dequeueing };
var is_dequeueing  = function(){ return _is_dequeueing() || queue.length };
JSTAPd.is_dequeueing = is_dequeueing;

// ajax base
var xhr = function(){
	return window.ActiveXObject ? new ActiveXObject("Microsoft.XMLHTTP") : new XMLHttpRequest();
};
JSTAPd.xhr = xhr;
var get = function(prefix, query, cb){
	var r = xhr();
	var uri = JSTAPd.jstapd_prefix + prefix + '?_='+(new Date).getTime();
	query.session = JSTAPd.session;
	query.path    = JSTAPd.path;
	var query_stack = [uri];
	for (k in query) {
		query_stack.push(encodeURIComponent(k) + '=' + encodeURIComponent(query[k]));
	}

	r.open('GET', query_stack.join('&'));
	r.onreadystatechange = function() {
		if (r.readyState == 4 && r.status == 200) {
			if (cb && typeof cb == 'function') cb(r);
			is_xhr_running--;
			dequeue();
		}
	}
	is_xhr_running++;
	r.send(null);
};
JSTAPd.get = get;
var tap = function(type, query, cb){
	query.type = type;
	get('tap', query, cb);
};

// util
window.tap$ = function(id){
	return document.getElementById(id);
};
window.tap$tag = function(tag){
	return document.getElementsByTagName(tag)[0];
};

// test functions for *.t file
JSTAPd.tap_count = 0;
JSTAPd.tap_tests = 0;
window.tests = function(num){
	JSTAPd.tap_tests = num;
	enqueue(function(){
		get('tests', { num: num });
	});
};
window.get_test_plans = function(cb){
	enqueue(function(){
		get('get_test_plans', {}, function(r){
			var json; eval('json = ' + r.responseText);
			cb(json);
		});
	});
};
window.ok   = function(val, msg){
	var ret;
	var comment = '';
	try {
		if (val) {
			ret = 'ok';
		} else {
			ret = 'not ok';
		}
	} catch(e) {
		comment = e;
	}

	enqueue(function(){
		tap('ok', {
			ret: ret,
			num: (++(JSTAPd.tap_count)),
			msg: msg,
			comment: comment
		});
	});
};
window.is   = function(got, expected, msg, is_not){
	var ret;
	var comment = '';
	try {
		if (got == expected) {
			ret = is_not ? 'not ok' : 'ok';
		} else {
			ret = is_not ? 'ok' : 'not ok';
		}
	} catch(e) {
		comment = e;
	}

	enqueue(function(){
		tap((is_not ? 'isnt' : 'is'), {
			ret: ret,
			num: (++(JSTAPd.tap_count)),
			msg: msg,
			got: got,
			expected: expected,
			comment: comment
		});
	});
};
window.isnt = function(got, expected, msg){
	is(got, expected, msg, true);
};
window.like = function(got, expected, msg, is_not){
	var ret;
	var comment = '';
	try {
		if (got.search(expected) >= 0) {
			ret = is_not ? 'not ok' : 'ok';
		} else {
			ret = is_not ? 'ok' : 'not ok';
		}
	} catch(e) {
		comment = e;
	}

	enqueue(function(){
		tap((is_not ? 'unlike' : 'like'), {
			ret: ret,
			num: (++(JSTAPd.tap_count)),
			msg: msg,
			got: got,
			expected: expected.toString(),
			comment: comment
		});
	});
};
window.unlike = function(got, expected, msg){
	like(got, expected, msg, true);
};

window.tap_done = function(error){
	enqueue(function(){
		get('tap_done', { error: error }, function(r){
			var div = document.createElement("div");
			div.innerHTML = r.responseText.replace(/\n/g, '<br>');
			tap$tag('body').appendChild(div);
			tap$('jstap_users_body_container').style.display = 'none';
		})
	});
};

window.tap_dump = function(){
	enqueue(function(){
		get('dump', {})
	});
};

window.pop_tap_request = function(cb, opts){
	enqueue(function(){
		get('pop_tap_request', (opts || {}), function(r){
			var json; eval('json = ' + r.responseText);
			cb(json);
		});
	});
};

window.tap_addevent = function(target, event, callback, useCapture){
	if (target.addEventListener) {
		target.addEventListener(event, callback, useCapture);
	} else if(target.attachEvent) {
		target.attachEvent('on'+event, callback);
	}
}

window.tap_xhr = function(){
	return xhr();
};
})();
