use strict;

package Test::Stream::Legacy::Builder::Tester;
package
    Test::Builder::Tester;

use Test::Stream;
use Test::Builder;
use Symbol;
use Test::Stream::Carp qw/croak/;
use Test::Stream::Context qw/context/;

####
# set up testing
####

#my $t = Test::Builder->new;

###
# make us an exporter
###

use Test::Stream::Toolset;
use Test::Stream::Exporter;
default_exports qw/test_out test_err test_fail test_diag test_test line_num/;
Test::Stream::Exporter->cleanup;

sub before_import {
    my $class = shift;
    my ($importer, $list) = @_;

    my $meta    = init_tester($importer);
    my $context = context(1);
    my $other   = [];
    my $idx     = 0;

    while ($idx <= $#{$list}) {
        my $item = $list->[$idx++];
        next unless $item;

        if (defined $item and $item eq 'no_diag') {
            Test::Stream->shared->set_no_diag(1);
        }
        elsif ($item eq 'tests') {
            $context->plan($list->[$idx++]);
        }
        elsif ($item eq 'skip_all') {
            $context->plan(0, 'SKIP', $list->[$idx++]);
        }
        elsif ($item eq 'no_plan') {
            $context->plan(0, 'NO PLAN');
        }
        elsif ($item eq 'import') {
            push @$other => @{$list->[$idx++]};
        }
    }

    @$list = @$other;

    return;
}


sub builder { Test::Builder->new }

###
# set up file handles
###

# create some private file handles
my $output_handle = gensym;
my $error_handle  = gensym;

# and tie them to this package
my $out = tie *$output_handle, "Test::Builder::Tester::Tie", "STDOUT";
my $err = tie *$error_handle,  "Test::Builder::Tester::Tie", "STDERR";

####
# exported functions
####

# for remembering that we're testing and where we're testing at
my $testing = 0;
my $testing_num;
my $original_is_passing;

my $original_hub;
my $original_state;

# remembering where the file handles were originally connected
my $original_output_handle;
my $original_failure_handle;
my $original_todo_handle;

my $original_harness_env;

# function that starts testing and redirects the filehandles for now
sub _start_testing {
    # even if we're running under Test::Harness pretend we're not
    # for now.  This needed so Test::Builder doesn't add extra spaces
    $original_harness_env = $ENV{HARNESS_ACTIVE} || 0;
    $ENV{HARNESS_ACTIVE} = 0;

    $original_hub = builder->{hub} || Test::Stream->shared;
    $original_state  = {%{$original_hub->state}};

    # remember what the handles were set to
    $original_output_handle  = builder()->output();
    $original_failure_handle = builder()->failure_output();
    $original_todo_handle    = builder()->todo_output();

    # switch out to our own handles
    builder()->output($output_handle);
    builder()->failure_output($error_handle);
    builder()->todo_output($output_handle);

    # clear the expected list
    $out->reset();
    $err->reset();

    # remember that we're testing
    $testing     = 1;
    $testing_num = builder()->current_test;
    builder()->current_test(0);
    $original_is_passing  = builder()->is_passing;
    builder()->is_passing(1);

    # look, we shouldn't do the ending stuff
    builder()->no_ending(1);
}

sub test_out {
    my $ctx = context;
    # do we need to do any setup?
    _start_testing() unless $testing;

    $out->expect(@_);
}

sub test_err {
    my $ctx = context;
    # do we need to do any setup?
    _start_testing() unless $testing;

    $err->expect(@_);
}

sub test_fail {
    my $ctx = context;
    # do we need to do any setup?
    _start_testing() unless $testing;

    # work out what line we should be on
    my( $package, $filename, $line ) = caller;
    $line = $line + ( shift() || 0 );    # prevent warnings

    # expect that on stderr
    $err->expect("#     Failed test ($filename at line $line)");
}

sub test_diag {
    my $ctx = context;
    # do we need to do any setup?
    _start_testing() unless $testing;

    # expect the same thing, but prepended with "#     "
    local $_;
    $err->expect( map { m/\S/ ? "# $_" : "" } @_ );
}

sub test_test {
    my $ctx = context;
    # decode the arguments as described in the pod
    my $mess;
    my %args;
    if( @_ == 1 ) {
        $mess = shift
    }
    else {
        %args = @_;
        $mess = $args{name} if exists( $args{name} );
        $mess = $args{title} if exists( $args{title} );
        $mess = $args{label} if exists( $args{label} );
    }

    # er, are we testing?
    croak "Not testing.  You must declare output with a test function first."
      unless $testing;

    # okay, reconnect the test suite back to the saved handles
    builder()->output($original_output_handle);
    builder()->failure_output($original_failure_handle);
    builder()->todo_output($original_todo_handle);

    # restore the test no, etc, back to the original point
    builder()->current_test($testing_num);
    $testing = 0;
    builder()->is_passing($original_is_passing);

    # re-enable the original setting of the harness
    $ENV{HARNESS_ACTIVE} = $original_harness_env;

    %{$original_hub->state} = %$original_state;

    # check the output we've stashed
    unless( builder()->ok( ( $args{skip_out} || $out->check ) &&
                    ( $args{skip_err} || $err->check ), $mess )
    )
    {
        # print out the diagnostic information about why this
        # test failed

        local $_;

        builder()->diag( map { "$_\n" } $out->complaint )
          unless $args{skip_out} || $out->check;

        builder()->diag( map { "$_\n" } $err->complaint )
          unless $args{skip_err} || $err->check;
    }
}


sub line_num {
    my( $package, $filename, $line ) = caller;
    return $line + ( shift() || 0 );    # prevent warnings
}

my $color;

sub color {
    $color = shift if @_;
    $color;
}

1;

####################################################################
# Helper class that is used to remember expected and received data

package Test::Stream::Legacy::Builder::Tester::Tie;
package
    Test::Builder::Tester::Tie;

##
# add line(s) to be expected

sub expect {
    my $self = shift;

    my @checks = @_;
    foreach my $check (@checks) {
        $check = $self->_account_for_subtest($check);
        $check = $self->_translate_Failed_check($check);
        push @{ $self->{wanted} }, ref $check ? $check : "$check\n";
    }
}

sub _account_for_subtest {
    my( $self, $check ) = @_;

    my $ctx = Test::Stream::Context::context();
    my $depth = @{$ctx->hub->subtests};
    # Since we ship with Test::Builder, calling a private method is safe...ish.
    return ref($check) ? $check : ($depth ? '    ' x $depth : '') . $check;
}

sub _translate_Failed_check {
    my( $self, $check ) = @_;

    if( $check =~ /\A(.*)#     (Failed .*test) \((.*?) at line (\d+)\)\Z(?!\n)/ ) {
        $check = "/\Q$1\E#\\s+\Q$2\E.*?\\n?.*?\Qat $3\E line \Q$4\E.*\\n?/";
    }

    return $check;
}

##
# return true iff the expected data matches the got data

sub check {
    my $self = shift;

    # turn off warnings as these might be undef
    local $^W = 0;

    my @checks = @{ $self->{wanted} };
    my $got    = $self->{got};
    foreach my $check (@checks) {
        $check = "\Q$check\E" unless( $check =~ s,^/(.*)/$,$1, or ref $check );
        return 0 unless $got =~ s/^$check//;
    }

    return length $got == 0;
}

##
# a complaint message about the inputs not matching (to be
# used for debugging messages)

sub complaint {
    my $self   = shift;
    my $type   = $self->type;
    my $got    = $self->got;
    my $wanted = join '', @{ $self->wanted };

    # are we running in colour mode?
    if(Test::Builder::Tester::color) {
        # get color
        eval { require Term::ANSIColor };
        unless($@) {
            # colours

            my $green = Term::ANSIColor::color("black") . Term::ANSIColor::color("on_green");
            my $red   = Term::ANSIColor::color("black") . Term::ANSIColor::color("on_red");
            my $reset = Term::ANSIColor::color("reset");

            # work out where the two strings start to differ
            my $char = 0;
            $char++ while substr( $got, $char, 1 ) eq substr( $wanted, $char, 1 );

            # get the start string and the two end strings
            my $start = $green . substr( $wanted, 0, $char );
            my $gotend    = $red . substr( $got,    $char ) . $reset;
            my $wantedend = $red . substr( $wanted, $char ) . $reset;

            # make the start turn green on and off
            $start =~ s/\n/$reset\n$green/g;

            # make the ends turn red on and off
            $gotend    =~ s/\n/$reset\n$red/g;
            $wantedend =~ s/\n/$reset\n$red/g;

            # rebuild the strings
            $got    = $start . $gotend;
            $wanted = $start . $wantedend;
        }
    }

    return "$type is:\n" . "$got\nnot:\n$wanted\nas expected";
}

##
# forget all expected and got data

sub reset {
    my $self = shift;
    %$self = (
        type   => $self->{type},
        got    => '',
        wanted => [],
    );
}

sub got {
    my $self = shift;
    return $self->{got};
}

sub wanted {
    my $self = shift;
    return $self->{wanted};
}

sub type {
    my $self = shift;
    return $self->{type};
}

###
# tie interface
###

sub PRINT {
    my $self = shift;
    $self->{got} .= join '', @_;
}

sub TIEHANDLE {
    my( $class, $type ) = @_;

    my $self = bless { type => $type }, $class;

    $self->reset;

    return $self;
}

sub READ     { }
sub READLINE { }
sub GETC     { }
sub FILENO   { }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Legacy::Builder::Tester - Compatability fork of
Test::Builder::Tester.

=head1 DESCRIPTION

This is a compatability fork of L<Test::Builder::Tester>. This module fully
implements the L<Test::Builder::Tester> API. This module exists to support
legacy modules, please do not use it to write new things.

=head1 SEE ALSO

See L<Test::Builder::Tester> for the actual documentation for using this
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
