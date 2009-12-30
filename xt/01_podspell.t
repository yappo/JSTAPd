use Test::More;
eval q{ use Test::Spelling };
plan skip_all => "Test::Spelling is not installed." if $@;
add_stopwords(map { split /[\s\:\-]/ } <DATA>);
$ENV{LANG} = 'C';
all_pod_files_spelling_ok('lib');
__DATA__
Kazuhiro Osawa
yappo <at> shibuya <döt> pl
lestrrat
cho45

JSTAPd
JSTAPd's
js
jstapd
jsDeferred
jstapDeferred
XmlHttpRequest

jQuery
API
api
DOM
XHR
Firefox
JSON
JavaScript
ajax
apiurl
callback
conf
eg
foo
msec
ok
ref
readyState
num
urlmap
urls
al
