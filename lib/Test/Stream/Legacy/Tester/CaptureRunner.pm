use strict;
use warnings;
package Test::Stream::Legacy::Tester::CaptureRunner;
package
    Test::Tester::CaptureRunner;

use Carp qw/croak/;
croak __PACKAGE__ . " is not supported under Test::Stream";

1;

__END__
