package Test::MostlyLike;
use strict;
use warnings;

use Test::Stream::Toolset;
use Test::Stream::Exporter;
default_exports qw/mostly_like/;
Test::Stream::Exporter->cleanup;

use Test::More::DeepCheck::Tolerant;

sub mostly_like {
    my ($got, $want, $name) = @_;

    my $ctx = context();

    unless( @_ == 2 or @_ == 3 ) {
        my $msg = <<'WARNING';
mostly_like() takes two or three args, you gave %d.
This usually means you passed an array or hash instead
of a reference to it
WARNING
        chop $msg;    # clip off newline so carp() will put in line/file

        $ctx->alert(sprintf $msg, scalar @_);

        $ctx->ok(0, undef, ['incorrect number of args']);
        return 0;
    }

    my ($ok, @diag) = Test::More::DeepCheck::Tolerant->check($got, $want);
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

1;

__END__

=head1 NAME

Test::MostlyLike - Relaxed checking of deep data structures.

=head1 SYNOPSYS

=head1 DESCRIPTION

A tool based on C<is_deeply> from L<Test::More>. This tool produces nearly
identical diagnostics. This tool gives you extra control by letting you check
only the parts of the structure you care about, ignoring the rest.

=head1 EXPORTS

=over 4

=item mostly_like($got, $expect, $name)

=back

=encoding utf8

=head1 SOURCE

The source code repository for Test::More can be found at
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

=item Test::MostlyLike

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::Simple

=item Test::More

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