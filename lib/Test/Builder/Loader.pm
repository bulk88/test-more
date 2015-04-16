package Test::Builder::Loader;
use strict;
use warnings;

package
    Test::Builder;

our $AUTOLOAD;

no warnings 'redefine';

sub AUTOLOAD {
    $AUTOLOAD =~ m/^(.*)::([^:]+)$/;
    my ($package, $sub) = ($1, $2);

    require Test::Builder;
    my $code = $package->can($sub);
    goto &$code if $code;

    my @caller = CORE::caller();
    die qq{Can't locate object method "$sub" via package "$package" at $caller[1] line $caller[2].\n};
}

1;
