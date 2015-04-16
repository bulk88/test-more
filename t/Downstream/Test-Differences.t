use strict;
use warnings;

use Test::Stream::Legacy;
use Test::Builder;
use Test::Stream::More;
use Test::Stream::Tester;
use Test::SkipWithout 'Test::Differences';
use ok 'Test::Differences';

events_are(
    intercept {
        eq_or_diff("apple", "apple", "pass");
        eq_or_diff("apple", "orange", "fail");
    },
    check {
        event ok => { pass => 1, name => 'pass' };
        event ok => { pass => 0, name => 'fail' };
        event diag => { message => <<"        EOT" };
+---+---------+----------+
| Ln|Got      |Expected  |
+---+---------+----------+
*  1|'apple'  |'orange'  *
+---+---------+----------+
        EOT
        directive 'end';
    },
    "Got expected events"
);

done_testing;
