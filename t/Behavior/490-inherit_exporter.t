use strict;
use warnings;


BEGIN {
    $INC{'My/Tester.pm'} = __FILE__;
    package My::Tester;
    use Test::Stream::More;
    use base 'Test::Stream::More';

    our @EXPORT    = (@Test::Stream::More::EXPORT, qw/foo/);
    our @EXPORT_OK = (@Test::Stream::More::EXPORT_OK);

    sub foo { goto &Test::Stream::More::ok }

    1;
}

use My::Tester;

can_ok(__PACKAGE__, qw/ok done_testing foo/);

foo(1, "This is just an ok");

done_testing;
