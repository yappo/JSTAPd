use JSTAPd::Suite;

sub client_script {
    return <<'DONE';
tests(15);

// show hide
$('.test').is_visible(5);
$('.test').hide();
$('.test').is_visible(0);
$('.test').isnt_visible();

$('#test1').show();
$('.test').is_visible(1);
$('#test3').show();
$('.test').is_visible(2);
$('#test5').show();
$('.test').is_visible(3);

// text value
$('.test').like_text(new RegExp('DATA'));
$('#test1').like_text(new RegExp('DATA1'));
$('#test2').unlike_text(new RegExp('DATA1'));
$('#test3').is_text('DATA3');
$('#test4').isnt_text('DATA3');

// form val
$('#in1').like_formval(new RegExp('foo'));
$('#in2').unlike_formval(new RegExp('foo'));
$('#in3').is_formval('baz');
$('#in4').isnt_formval('hoge');
DONE
}

sub html_body {
    return <<'DONE';
<div class="test" id='test1'>DATA1</div>
<div class="test" id='test2'>DATA2</div>
<div class="test" id='test3'>DATA3</div>
<div class="test" id='test4'>DATA4</div>
<div class="test" id='test5'>DATA5</div>
<input id="in1" value="foo">
<input id="in2" value="bar">
<input id="in3" value="baz">
<input id="in4" value="boo">
DONE
}

sub include_ex {
#    'http://ajax.googleapis.com/ajax/libs/jquery/1.3.2/jquery.min.js',
    '/jslib/jquery-1.3.2.min.js',
    \'jquery-jstapd.js',
 }
