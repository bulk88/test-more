use strict;
use warnings;

use Test::Stream::Legacy;
use Test::SkipWithout 'Test::Class';
use Test::Stream::More;
use Test::Stream::Tester;
use ok 'Test::Class';

{
    package Foo;
    use Test::Stream::More;
    use base 'Test::Class';

    sub a_test : Test {
        ok(1, "pass");
    }

    sub b_test : Test {
        ok(1, "pass");
    }
}

events_are(
    intercept { Test::Class->runtests },
    check {
        directive seek => 1;
        event plan => { max => 2 };
        event ok => { pass => 1 };
        event ok => { pass => 1 };
    },
    "Got events"
);

done_testing;
