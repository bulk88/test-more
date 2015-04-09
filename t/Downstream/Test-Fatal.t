use strict;
use warnings;

use Test::Stream::Legacy;
use Test::SkipWithout 'Test::Fatal';
use Test::Stream::More;
use Test::Stream::Tester;
use ok 'Test::Fatal';

events_are(
    intercept {
        ok(1, "pass");
        like( exception { die "xxx" }, qr/xxx/ );
        is( exception { 1 }, undef );
    },
    check {
        event ok => { pass => 1 };
        event ok => { pass => 1 };
    },
    "Got expected events"
);

done_testing;
