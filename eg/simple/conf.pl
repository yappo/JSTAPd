# JSTAPd config
my $config = {
    jstapd_prefix => '____jstapd',
    apiurl        => qr!^/api/!,
};
$config->{urlmap} = [
    { qr!^/jslib/! => '../jslib/' },
];
$config;
