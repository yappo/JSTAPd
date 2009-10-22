use JSTAPd::Suite;

sub client_script {
    return <<'DONE';
tests(1);
ok('done', 'done');
DONE
}
