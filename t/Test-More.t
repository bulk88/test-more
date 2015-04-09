use strict;
use warnings;

use Test::Stream::Legacy;
use ok 'Test::Stream::More';

{
    package Foo;
    use Test::Stream::More import => ['!explain'];
}

{
    package Bar;
    BEGIN { main::use_ok('Scalar::Util', 'blessed') }
    BEGIN { main::can_ok('Bar', qw/blessed/) }
    blessed('x');
}

{
    package Baz;
    use Test::Stream::More;
    use_ok( 'Data::Dumper' );
    can_ok( __PACKAGE__, 'Dumper' );
    Dumper({foo => 'bar'});
}

can_ok('Foo', qw/ok is plan/);
ok(!Foo->can('explain'), "explain was not imported");

done_testing;
