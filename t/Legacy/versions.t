#!/usr/bin/perl -w
use Test::Stream::Legacy;

# Make sure all the modules have the same version
#
# TBT has its own version system.

use strict;
use Test::Stream::Legacy;
use Test::Stream::More;

{
    local $SIG{__WARN__} = sub { 1 };
    require Test::Builder::Module;
    require Test::Builder::Tester::Color;
    require Test::Builder::Tester;
    require Test::Builder;
    require Test::More;
    require Test::Simple;
    require Test::Stream;
    require Test::Stream::Tester;
    require Test::Tester;
}

my $dist_version = '100.001001';

like( $dist_version, qr/^ \d+ \. \d+ $/x, "Version number is sane" );

my @modules = qw(
    Test::Builder::Module
    Test::Builder::Tester::Color
    Test::Builder::Tester
    Test::Builder
    Test::More
    Test::Simple
    Test::Stream
    Test::Stream::Tester
    Test::Tester
);

for my $module (@modules) {
    my $file = $module;
    $file =~ s{(::|')}{/}g;
    $file .= ".pm";
    is( $module->VERSION, $module->VERSION, sprintf("%-22s %s", $module, $INC{$file}) );
}

done_testing();
