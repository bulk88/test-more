use strict;
use warnings;

use Test::Stream::Legacy;
use Test::SkipWithout 'Test::Warn';
use Test::Stream::More;
use Test::Stream::Tester;
use ok 'Test::Warn';

events_are(
    intercept {
        warning_is { warn 'a' } 'a';
        warning_is { warn 'b' } 'a';

        warnings_are { warn 'a'; warn 'b' } [ 'a', 'b' ];
        warnings_are { warn 'b'; warn 'a' } [ 'a', 'b' ];
        warnings_are { 1 } [];

        warning_like { warn "a xxx a" } qr/xxx/;
        warning_like { warn "a xxx a" } qr/aaa/;
    },
    check {
        directive 'seek' => 1;
        event ok => { pass => 1 };
        event ok => { pass => 0 };

        event ok => { pass => 1 };
        event ok => { pass => 0 };
        event ok => { pass => 1 };

        event ok => { pass => 1 };
        event ok => { pass => 0 };
    },
    "Got expected events"
);

done_testing;
