use strict;
use warnings;
use Test::Stream;
use Test::Stream::Legacy;
use Test::Stream::Tester;
use Test::Stream::More;
use Test::Builder;

my $tb = Test::Builder->new;

events_are(
    intercept {
        for (1, 2, 3) {
            $tb->reset;
            $tb->ok(1);
            $tb->ok(2);
            $tb->done_testing;
        }
    },
    check {
        event ok   => {effective_pass => 1};
        event ok   => {effective_pass => 1};
        event plan => {max  => 2};

        event ok   => {effective_pass => 1};
        event ok   => {effective_pass => 1};
        event plan => {max  => 2};

        event ok   => {effective_pass => 1};
        event ok   => {effective_pass => 1};
        event plan => {max  => 2};

        dir 'end';
    },
    "Reset works"
);

done_testing;
