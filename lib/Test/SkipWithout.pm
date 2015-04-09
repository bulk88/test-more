package Test::SkipWithout;
use strict;
use warnings;

sub import {
    my $class = shift;
    my ($module, $version) = @_;

    my ($pkg, $file, $line) = caller;

    my $ok = eval qq{require $module; 1};
    my $err = $@;

    unless ($ok) {
        # This will probably break in perl5i since it changes the message, oh well.
        return skip("$module is not installed, skipping test.")
            if $err =~ m/Can't locate .* in \@INC/;

        die "Error loading module '$module' at $file line $line.\n$err";
    }

    return unless $version;

    $ok = eval {$module->VERSION($version)};
    $err = $@;
    return if $ok;

    my $f = __FILE__;
    $err =~ s/ at $f.*//;
    skip($err);
}

sub skip {
    my ($reason) = @_;

    require Test::Stream::More;
    Test::Stream::More::plan('skip_all' => $reason);

    exit 0;
}

1;

__END__

=head1 NAME

Test::SkipWithout - Skip a test if a module is missing, or an insufficient
version.

=head1 DESCRIPTION

Sometimes a test should only run if specific modules are installed. Other times
a test should only run when a sufficient version of a module is available. This
module lets you do this quickly without writing your own evals.

This Module will skip if the conditions are not met. It is also smart enough to
notice when a module fails to load, or fails its version check due to an
exception. All exceptions are rethrown except for those related to a version
mismatch or module not being installed.

=head1 SYNOPSYS

    use Test::SkipWithout 'My::Widget';

    use Test::Stream::More;

    my $widget = My::Widget->new;

    ok($widget, "Made a widget!");

    done_testing;

You can also specify a minimum version

    use Test::SkipWithout 'My::Widget' => '2.005';

    use Test::More;

    my $widget = My::Widget->new;

    ok($widget, "Made a widget!");

    done_testing;

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2014 Chad Granum

Test-SkipWithout is free software; Standard perl licence.

Test-SkipWithout is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the license for more details.
