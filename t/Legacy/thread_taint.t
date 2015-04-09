#!/usr/bin/perl -w
use Test::Stream::Legacy;

use Test::More tests => 1;

ok( !$INC{'threads.pm'}, 'Loading Test::More does not load threads.pm' );
