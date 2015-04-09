use strict;
use warnings;

use Test::Stream::Legacy;
use Test::SkipWithout 'Test::Trap';
use Test::Stream::More;
use ok 'Test::Trap';

trap { exit 100 };
is($trap->exit, 100, "got exit");

done_testing;
