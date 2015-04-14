use strict;

package Test::Stream::Legacy::Builder::Module;
package
    Test::Builder::Module;

use Test::Stream;
use Test::Builder;

require Exporter;
our @ISA = qw(Exporter);

sub import {
    my($class) = shift;

    my $test = $class->builder;
    my $caller = caller;

    warn __PACKAGE__ . " is deprecated!\n" if $caller->can('TB_INSTANCE') && $caller->TB_INSTANCE->modern;

    # Don't run all this when loading ourself.
    return 1 if $class eq 'Test::Builder::Module';


    $test->exported_to($caller);

    $class->import_extra( \@_ );
    my(@imports) = $class->_strip_imports( \@_ );

    $test->plan(@_);

    $class->export_to_level( 1, $class, @imports );
}

sub _strip_imports {
    my $class = shift;
    my $list  = shift;

    my @imports = ();
    my @other   = ();
    my $idx     = 0;
    while( $idx <= $#{$list} ) {
        my $item = $list->[$idx];

        if( defined $item and $item eq 'import' ) {
            push @imports, @{ $list->[ $idx + 1 ] };
            $idx++;
        }
        else {
            push @other, $item;
        }

        $idx++;
    }

    @$list = @other;

    return @imports;
}

sub import_extra { }

sub builder {
    return Test::Builder->new;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Legacy::Builder::Module - Compatability fork of
Test::Builder::Module.

=head1 DESCRIPTION

This is a compatability fork of L<Test::Builder::Module>. This module fully
implements the L<Test::Builder::Module> API. This module exists to support
legacy modules, please do not use it to write new things.

=head1 SEE ALSO

See L<Test::Builder::Module> for the actual documentation for using this
module.

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINER

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

The following people have all contributed to the Test-More dist (sorted using
VIM's sort function).

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Fergal Daly E<lt>fergal@esatclear.ie>E<gt>

=item Mark Fowler E<lt>mark@twoshortplanks.comE<gt>

=item Michael G Schwern E<lt>schwern@pobox.comE<gt>

=item 唐鳳

=back

=head1 COPYRIGHT

There has been a lot of code migration between modules,
here are all the original copyrights together:

=over 4

=item Test::Stream

=item Test::Stream::Tester

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::Simple

=item Test::Stream::More

=item Test::Builder

Originally authored by Michael G Schwern E<lt>schwern@pobox.comE<gt> with much
inspiration from Joshua Pritikin's Test module and lots of help from Barrie
Slaymaker, Tony Bowden, blackstar.co.uk, chromatic, Fergal Daly and the perl-qa
gang.

Idea by Tony Bowden and Paul Johnson, code by Michael G Schwern
E<lt>schwern@pobox.comE<gt>, wardrobe by Calvin Klein.

Copyright 2001-2008 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::use::ok

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to L<Test-use-ok>.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=item Test::Tester

This module is copyright 2005 Fergal Daly <fergal@esatclear.ie>, some parts
are based on other people's work.

Under the same license as Perl itself

See http://www.perl.com/perl/misc/Artistic.html

=item Test::Builder::Tester

Copyright Mark Fowler E<lt>mark@twoshortplanks.comE<gt> 2002, 2004.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=back
