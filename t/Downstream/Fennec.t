use strict;
use warnings;

use Test::Stream::Legacy;
use Test::SkipWithout 'Fennec';
use Test::Stream::More;
use ok 'Fennec';

describe foo => sub {
    tests bar => sub {
        ok(1, "one");
        ok(2, "two");
    };
};

done_testing;
