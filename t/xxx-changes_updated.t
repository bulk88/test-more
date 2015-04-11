use strict;
use warnings;
use Test::Stream;
use Test::Stream::More;
use List::Util qw/first/;

plan skip_all => "Only tested when releasing" unless $ENV{AUTHOR_TESTING};

my $ver = $Test::Stream::VERSION;
$ver =~ s/^(\d+\.\d{6}).*$/$1/;

my $changes = first { -f $_ } './Changes', '../Changes';

die "Could not find the Changes file"
    unless $changes;

open(my $fh, '<', $changes) || die "Could not load changes file!";
chomp(my $line = <$fh>);
like($line, qr/^\Q$ver\E/, "Changes file is up to date");
close($fh);

done_testing;
