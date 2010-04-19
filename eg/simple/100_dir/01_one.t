use JSTAPd::Suite;

sub tests { 1 }

sub client_script {
    return <<'DONE';
ok('done', 'done');
DONE
}
