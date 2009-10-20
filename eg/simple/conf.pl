# JSTAPd config
my $config = {};
$config->{urlmap} = [
    { qr!^/jslib/! => '../jslib/' },
];
$config;
