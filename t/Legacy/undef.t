#!/usr/bin/perl -w
use Test::Stream::Legacy;

BEGIN {
    unshift @INC, 't/lib';
}

use strict;
use Test::More;

BEGIN {
    require warnings;
    if( eval "warnings->can('carp')" ) {
        plan skip_all => 'Modern::Open is installed, which breaks this test';
    }
}

BEGIN { $^W = 1; }

my $warnings = '';
local $SIG{__WARN__} = sub { $warnings .= join '', @_ };

my $TB = Test::Builder->new;
sub no_warnings {
    $TB->is_eq($warnings, '', '  no warnings');
    $warnings = '';
}

sub warnings_is {
    $TB->is_eq($warnings, $_[0]);
    $warnings = '';
}

sub warnings_like {
    $TB->like($warnings, $_[0]);
    $warnings = '';
}


my $Filename = quotemeta $0;


is( undef, undef,           'undef is undef');
no_warnings;

isnt( undef, 'foo',         'undef isnt foo');
no_warnings;

isnt( undef, '',            'undef isnt an empty string' );
isnt( undef, 0,             'undef isnt zero' );

Test::More->builder->is_num(undef, undef, 'is_num()');
Test::More->builder->isnt_num(23, undef,  'isnt_num()');

#line 45
like( undef, qr/.*/,        'undef is like anything' );
no_warnings;

eq_array( [undef, undef], [undef, 23] );
no_warnings;

eq_hash ( { foo => undef, bar => undef },
          { foo => undef, bar => 23 } );
no_warnings;

eq_set  ( [undef, undef, 12], [29, undef, undef] );
no_warnings;


eq_hash ( { foo => undef, bar => { baz => undef, moo => 23 } },
          { foo => undef, bar => { baz => undef, moo => 23 } } );
no_warnings;


#line 74
cmp_ok( undef, '<=', 2, '  undef <= 2' );
warnings_like(qr/Use of uninitialized value.* at \(eval in cmp_ok\) $Filename line 74\.\n/);



my $tb = Test::More->builder;

my $err = '';
$tb->failure_output(\$err);
diag(undef);
$tb->reset_outputs;

is( $err, "# undef\n" );
no_warnings;


$tb->maybe_regex(undef);
no_warnings;


# test-more.googlecode.com #42
{
    is_deeply([ undef ], [ undef ]);
    no_warnings;
}

done_testing;
