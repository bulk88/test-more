use strict;
use warnings;

use Test::SkipWithout 'Test::Stream' => '0.001001';
use Test::Stream::More;

use Test::Stream::Tester;

events_are(
    intercept {
        Test::SkipWithout->import('fake::module::dfasdhfafahgsdahfgashdfashgfgdgasdgfs');
        fail("Should not see this!");
    },
    check {
        event plan => {
            directive => 'SKIP',
            reason => 'fake::module::dfasdhfafahgsdahfgashdfashgfgdgasdgfs is not installed, skipping test.',
        };
        directive 'end';
    },

    "Skip from missing module"
);

events_are(
    intercept {
        Test::SkipWithout->import('Test::Stream' => '9000.001');
        fail("Should not see this!");
    },
    check {
        event plan => {
            directive => 'SKIP',
            reason => qr/^Test::Stream version 9000\.001 required--this is only version/,
        };
        directive 'end';
    },

    "Skip from insufficient version"
);

events_are(
    intercept {
        Test::SkipWithout->import('Test::Stream' => '0.001001');
        pass("Should see this!");
    },
    check {
        event ok => { pass => 1, name => 'Should see this!' };
        directive 'end';
    },

    "No Skip"
);

done_testing;
