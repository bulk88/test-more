#!/usr/bin/perl -w
use Test::Stream::Legacy;

# plan() used to export functions by mistake [rt.cpan.org 8385]

use Test::More ();
Test::More::plan(tests => 1);

Test::More::ok( !__PACKAGE__->can('ok'), 'plan should not export' );
