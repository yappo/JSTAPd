(function(){

var status = {
	tests: []
};
var current_path = '';
function start_next(args){
	var body = tap$tag('body');

	var h = document.createElement("h2");
	var a = document.createElement("a");
	a.href = JSTAPd.contents_prefix + args.path;
	a.target = '_blank';
	a.innerHTML = args.path;
	a.name = args.path;
	h.appendChild(a);
	body.appendChild(h);

	var iframe_div = document.createElement("div");
	body.appendChild(iframe_div);

	var iframe = document.createElement("iframe");
	iframe_div.appendChild(iframe);
	iframe.src = JSTAPd.contents_prefix + JSTAPd.path + '?session=' + JSTAPd.session;
	iframe.width = '100%%';

	JSTAPd.get('watch_finish', {}, function(r){
		var json; eval('json = ' + r.responseText);
		if (json.status != 0 && json.session == JSTAPd.session && json.path == JSTAPd.path) {
			finish_and_next(json.tap, json.path, h);
		} else {
			alert("error?");
		}
	});
}

function finish_and_next(json, name, h){
	var msg = ' .. ';
	var is_ok = 0;
	if (json.fail > 0) {
		msg += json.ok + '/' + json.run;
	} else if (json.error) {
		msg += json.ok + '/' + json.run + ' ' + json.error;
	} else {
		msg += 'ok';
		is_ok = 1;
	}
	if (json.tests > 0 && json.tests != json.run) {
		msg += ' # Looks like you planned ' + json.tests + ' test but ran ' + json.run + '.';
		is_ok = 0;
	}

	var span = document.createElement("span");
	span.innerHTML = msg;
	h.appendChild(span);

	status.tests.push({ name: name, msg: msg, is_ok: is_ok });
	get_next();
}

function all_tests_finish(){

	var ul = document.createElement("ul");

	var fails = 0;
	for (i in status.tests) {
		var ret = status.tests[i];
		var li = document.createElement("li");
		var a = document.createElement("a");
		a.href = '#' + ret.name;
		a.innerHTML = ret.name + ret.msg;
		li.appendChild(a);
		ul.appendChild(li);
		if (!ret.is_ok) fails++;
	}
	var results = tap$('results');
	results.appendChild(ul);

	var div1 = document.createElement("div");
	div1.innerHTML = 'Tests=' + status.tests.length + ', Fails=' + fails;
	results.appendChild(div1);
    
	var div2 = document.createElement("div");
	if (fails == 0) {
		div2.innerHTML = 'Result: PASS';
	} else {
		div2.innerHTML = 'Result: FAIL';
	}
	results.appendChild(div2);

	if (JSTAPd.run_once) {
		JSTAPd.get('exit', {}, function(r){ /* nothing response */ });
		setTimeout(function(){
			if (JSTAPd.auto_open) window.close();
		}, 100);
	}
}

function get_next(){
	JSTAPd.get('get_next', {}, function(r){
		var json; eval('json = ' + r.responseText);
		if (!json.session) return;
		if (json.path == '-1') {
			all_tests_finish();
			return;
		}
		JSTAPd.session = json.session;
		JSTAPd.path    = json.path;
		start_next(json);
	});
}


window.onload = function(){
	var button = tap$('make-test');
	if (JSTAPd.run_once) {
		button.style.display = 'none';
		get_next();
	} else {
		button.onclick = function(){
			get_next();
		};
	}
};
})();
