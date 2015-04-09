use strict;
use warnings;

use Test::Stream::Legacy;
use Test::CanThread qw/AUTHOR_TESTING/;
use Test::Stream::More tests => 4;
use Test::Builder;

ok(1, "outside before");

my $run = sub {
    ok(1, 'in thread1');
    ok(1, 'in thread2');
};


my $t = threads->create($run);

ok(1, "outside after");

$t->join;

END {
    print "XXX: " . Test::Builder->new->is_passing . "\n";
}
