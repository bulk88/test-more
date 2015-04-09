use strict;
use Test::Stream::Legacy;

BEGIN { $| = 1; $^W = 1; }

use Test::Simple tests => 3;

ok(1, 'compile');

ok(1);
ok(1, 'foo');
