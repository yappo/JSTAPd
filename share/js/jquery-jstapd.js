(function ($) {

$.fn.is_visible = function(num){
	window.is($($(this).selector+':visible').length, num, $(this).selector + ' is visible ' + num + ' items');
	return this;
};

$.fn.isnt_visible = function(){
	var ret = 0;
	if ($($(this).selector+':visible').length == 0) {
		ret = 1;
	}
	window.ok(ret, $(this).selector + ' is not visible');
	return this;
};

$.fn.is_text = function(val){
	window.is($(this).text(), val, $(this).selector + " text() is '" + val + "'");
	return this;
};

$.fn.isnt_text = function(val){
	window.isnt($(this).text(), val, $(this).selector + " text() is not '" + val + "'");
	return this;
};

$.fn.like_text = function(val){
	window.like($(this).text(), val, $(this).selector + " text() like '" + val.toString() + "'");
	return this;
};

$.fn.unlike_text = function(val){
	window.unlike($(this).text(), val, $(this).selector + " text() unlike '" + val.toString() + "'");
	return this;
};

$.fn.is_formval = function(val){
	window.is($(this).val(), val, $(this).selector + " form val() is '" + val + "'");
	return this;
};

$.fn.isnt_formval = function(val){
	window.isnt($(this).val(), val, $(this).selector + " form val() is not '" + val + "'");
	return this;
};

$.fn.like_formval = function(val){
	window.like($(this).val(), val, $(this).selector + " form val() like '" + val.toString() + "'");
	return this;
};

$.fn.unlike_formval = function(val){
	window.unlike($(this).val(), val, $(this).selector + " form val() unlike '" + val.toString() + "'");
	return this;
};

$.fn.is_attr = function(name, val){
	window.is($(this).attr(name), val, $(this).selector + " '" + name + "' attr is '" + val + "'");
	return this;
};

$.fn.ok_hasClass = function(val){
	window.ok($(this).hasClass(val), $(this).selector + " hasClass '" + val + "'");
	return this;
};

$.fn.ok_hasntClass = function(val){
	window.ok(!$(this).hasClass(val), $(this).selector + " hasntClass '" + val + "'");
	return this;
};

$.fn.has_items_of = function(val){
	window.is($(this).length, val, $(this).selector + " has items of " + val + "");
	return this;
};

})(jQuery);
