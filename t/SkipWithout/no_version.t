use strict;
use warnings;

use Test::Stream::More;

# Check that we aren't a sufficient version
use Test::SkipWithout 'Test::SkipWithout' => '9000.001';

fail("should not see this");

done_testing;
