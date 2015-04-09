#!/usr/bin/perl -w
use Test::Stream::Legacy;

BEGIN {
    unshift @INC, 't/lib';
}

use Test::More;

my $result;
BEGIN {
    $result = use_ok("strict");
}

ok( $result, "use_ok() ran" );
done_testing(2);

