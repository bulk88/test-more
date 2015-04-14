package Test::Stream::Legacy;
use strict;
use warnings;

use Test::Stream::Carp qw/confess/;

# Avoid string manip
our %ALT_FILES = (
    'Test/More.pm'   => 'Test/Stream/More.pm',
    'Test/Simple.pm' => 'Test/Stream/Simple.pm',

    'Test/Builder.pm'        => 'Test/Stream/Legacy/Builder.pm',
    'Test/Builder/Module.pm' => 'Test/Stream/Legacy/Builder/Module.pm',

    'Test/Tester.pm'               => 'Test/Stream/Legacy/Tester.pm',
    'Test/Tester/Capture.pm'       => 'Test/Stream/Legacy/Tester/Capture.pm',
    'Test/Tester/Delegate.pm'      => 'Test/Stream/Legacy/Tester/Delegate.pm',
    'Test/Tester/CaptureRunner.pm' => 'Test/Stream/Legacy/Tester/CaptureRunner.pm',

    'Test/Builder/Tester.pm'       => 'Test/Stream/Legacy/Builder/Tester.pm',
    'Test/Builder/Tester/Color.pm' => 'Test/Stream/Legacy/Builder/Tester/Color.pm',
);

# Avoid string manip
our %PACKAGE_MAP = (
    # Reals
    'Test/More.pm'   => 'Test::More',
    'Test/Simple.pm' => 'Test::Simple',

    'Test/Builder.pm'        => 'Test::Builder',
    'Test/Builder/Module.pm' => 'Test::Builder::Module',

    'Test/Tester.pm'               => 'Test::Tester',
    'Test/Tester/Capture.pm'       => 'Test::Tester::Capture',
    'Test/Tester/Delegate.pm'      => 'Test::Tester::Delegate',
    'Test/Tester/CaptureRunner.pm' => 'Test::Tester::CaptureRunner',

    'Test/Builder/Tester.pm'       => 'Test::Builder::Tester',
    'Test/Builder/Tester/Color.pm' => 'Test::Builder::Tester::Color',

    # Alts
    'Test/Stream/More.pm'   => 'Test::Stream::More',
    'Test/Stream/Simple.pm' => 'Test::Stream::Simple',

    'Test/Stream/Legacy/Builder.pm'        => 'Test::Builder',
    'Test/Stream/Legacy/Builder/Module.pm' => 'Test::Builder::Module',

    'Test/Stream/Legacy/Tester.pm'               => 'Test::Tester',
    'Test/Stream/Legacy/Tester/Capture.pm'       => 'Test::Tester::Capture',
    'Test/Stream/Legacy/Tester/Delegate.pm'      => 'Test::Tester::Delegate',
    'Test/Stream/Legacy/Tester/CaptureRunner.pm' => 'Test::Tester::CaptureRunner',

    'Test/Stream/Legacy/Builder/Tester.pm'       => 'Test::Builder::Tester',
    'Test/Stream/Legacy/Builder/Tester/Color.pm' => 'Test::Builder::Tester::Color',
);

my $FAKE_VER = '100.001001';

sub load_alt {
    my ($real) = @_;

    load_alt('Test/Builder.pm')
        unless $INC{'Test/Builder.pm'}
            || $real eq 'Test/Builder.pm';

    my $alt = $ALT_FILES{$real} || die "No alternate file for '$real'";

    my $out = require $alt;

    my $alt_pkg  = $PACKAGE_MAP{$alt};
    my $real_pkg = $PACKAGE_MAP{$real};

    my @legacies = ($real_pkg);
    {
        no strict 'refs';
        ${"$real\::VERSION"} = $FAKE_VER;

        # The following alias borks things...
        #*{"$real_pkg\::"} = *{"$alt_pkg\::"} unless $alt_pkg eq $real_pkg;

        unless ($alt_pkg eq $real_pkg) {
            # Get stashes
            my $stream = \%{"$alt_pkg\::"};
            my $legacy = \%{"$real_pkg\::"};

            # Alias all symbols
            for my $sym (sort keys %$stream) {
                next if $sym =~ m/::$/;
                next if $sym eq '__ANON__';
                #Should profile both variants
                #*{"$real_pkg\::$sym"} = *{"$alt_pkg\::$sym"};
                $legacy->{$sym} = $stream->{$sym};
            }
        }
    }

    # Mark package as loaded.
    $INC{$real} = $alt;

    # Alias meta for exporter and hashbase
    require Test::Stream::HashBase::Meta;
    require Test::Stream::Exporter::Meta;
    Test::Stream::HashBase::Meta->alias($alt_pkg, $real_pkg);
    Test::Stream::Exporter::Meta->alias($alt_pkg, $real_pkg);

    $out;
};

sub loader {
    my ($sub, $file) = @_;
    return unless $ALT_FILES{$file};

    load_alt($file);

    return \"1";
}

my $LOADED = 0;
sub import {
    my $class = shift;
    return if $LOADED++;

    unshift @INC => \&loader;
    $class->takeover;
}

sub unimport {
    my $class = shift;
    return unless $LOADED;
    $LOADED = 0;
    @INC = grep { !(ref($_) && $_ == \&loader) } @INC;
}

sub takeover {
    return unless $INC{'Test/Builder.pm'}
               && $INC{'Test/Builder.pm'} !~ m(/\Q$ALT_FILES{'Test/Builder.pm'}\E$);

    my $list = "  Test::Builder\n";

    my $tb = Test::Builder->new;
    my $tb_data = {%$tb};
    %$tb = ();

    wipe_namespace($PACKAGE_MAP{'Test/Builder.pm'});

    $Test::Builder::Test = $tb;

    load_alt('Test/Builder.pm');
    upgrade_to_stream($tb_data);

    for my $file (sort keys %ALT_FILES) {
        next if $file eq 'Test/Builder.pm';    # Already Handled
        next unless $INC{$file};               # Not Loaded
        next if $INC{$file} =~ m(/\Q$ALT_FILES{$file}\E$);    # Loaded the right one
        my $package = $PACKAGE_MAP{$file};
        $list .= "  $package\n";

        wipe_namespace($package);
        load_alt($file);
    }

    warn <<"    EOT";
Something loaded Test::Stream, but Test::Builder is already loaded.
Attempting to unload the follwing modules and upgrade them with Test::Stream
alternatives:
$list
In most cases this will work fine, but it will generate this annoying warning.
To make this message go away you should use Test::Stream::Legacy near the start
of your test file, before loading any other testing tools.
    EOT
}

sub wipe_namespace {
    my ($pkg) = @_;

    no strict 'refs';
    my $stash = \%{"${pkg}\::"};

    for my $key (keys %$stash) {
        next if $key =~ m/::$/;
        next if $key eq '__ANON__';
        delete $stash->{$key};
    }
}

sub upgrade_to_stream {
    my $tb = shift;

    # May be possible, but is the WRONG type of crazy
    confess "Cannot replace Test::Builder during a subtest!"
        if $tb->{Parent};

    confess "Cannot replace Test::Builder in a child process!"
        if $tb->{Original_Pid} != $$;

    confess "Cannot replace Test::Builder after done_testing has been called!"
        if $tb->{Done_Testing};

    confess "Cannot replace Test::Builder during the ending phase!"
        if $tb->{Ending};

    confess "Cannot replace Test::Builder after a skip all!"
        if $tb->{Skip_All};

    require Test::Stream;
    my $hub = Test::Stream->shared;
    my $state = $hub->state;
    my $ioset = $hub->io_sets;

    # Update plan
    if ($tb->{Have_Plan}) {
        require Test::Stream::Event::Plan;
        require Test::Stream::Context;
        my $ctx = Test::Stream::Context::context()->snapshot;
        my $plan = $ctx->build_event('Plan',
            max => $tb->{Expected_Tests},
            $tb->{No_Plan} ? (directive => 'NO PLAN') : (),
        );
        $state->set_plan($plan);
        $state->set_ended($ctx);
    }

    # Set state and Legacy results
    $state->set_count($tb->{Curr_Test});
    $state->is_passing($tb->{Is_Passing} ? 1 : 0);
    $state->set_failed(scalar grep { !$_->{'ok'} } @{$tb->{'Test_Results'} || []});
    $state->push_legacy(@{$tb->{'Test_Results'} || []});

    # Set filehandles
    $ioset->{legacy} = [$tb->{Out_FH}, $tb->{Fail_FH}, $tb->{Todo_FH}];

    $hub->set_no_ending(1) if $tb->{No_Ending};
    $hub->set_no_header(1) if $tb->{No_Header};
    $hub->set_no_diag(1)   if $tb->{No_Diag};

    $hub->set_use_numbers(0) unless $tb->{Use_Nums};

    # todo settings
    my $ntb = Test::Builder->new;
    $ntb->{Start_Todo} = $tb->{Start_Todo};
    $ntb->{Todo_Stack} = $tb->{Todo_Stack};
    $ntb->{Todo}       = $tb->{Todo};

    $Test::Builder::Test->reset(shared_hub => 1, init => 1);

    if (my $pkg = $tb->{Exported_To}) {
        require Test::Stream::More;

        Test::Stream::Exporter::export_to(
            'Test::Stream::More',
            $pkg,
            '-override',
        );
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Legacy - Legacy support for Test::Builder based tools while using
Test::Stream.

=head1 SYNOPSIS

=head2 IN CODE

    use Test::Stream::Legacy;
    use Legacy::Test::Tool;
    ...

Using Test::Stream automatically loads Test::Stream::Legacy for you. So does
loading any tool that loads Test::Stream.

    use Test::Stream;

You can also unload Test::Stream::Legacy, this will not unload any legacy
namespaces (like Test::Builder) but it will prevent the legacy tools from
loading in the future.

    use Test::Stream;        # This loads legacy support for you.
    no Test::Stream::Legacy; # Turn off legacy support.
    use Test::Builder;       # Will load the original Test::Builder

=head2 AT THE SHELL

You can have Test::Stream::Legacy load automatically before tests run using the
C<PERL5OPTS> environment variable. Doing this will force the tests to run
through Test::Stream even if no tool requests it. This is a good way to check
if your testing tool still works under Test::Stream.

    $ PERL5OPTS="-MTest::Stream::Legacy" prove -r ./t

=head1 DESCRIPTION

This module inserts a value into the front of C<@INC> that redirects some
module loads. Instead of loading the modules you ask for, it loads some
Test::Stream specific ones that are bundled with Test::Stream. These
implementations make it possible to use legacy Test::* modules in tests that
load Test::Stream.

=head1 MODULE REDIRECTS

=over 4

=item Test/Builder.pm -> Test/Stream/Legacy/Builder.pm

L<Test::Stream::Legacy::Builder> is an implementation of L<Test::Builder> that
wraps around L<Test::Stream> so that L<Test::Builder> based tools will play
nicely with L<Test::Stream> based tools.

=item Test/More.pm -> Test/Stream/More.pm

L<Test::Stream::More> is a drop-in fully compatible replacement for
L<Test::More>. The original L<Test::More> would actually work just fine under
L<Test::Stream> so long as L<Test::Stream::Legacy::Builder> was loaded, however
this implementation is significantly more efficient.

=item Test/Simple.pm -> Test/Stream/Simple.pm

L<Test::Stream::Simple> is a drop-in fully compatible replacement for
L<Test::Simple>. The original L<Test::Simple> would actually work just fine
under L<Test::Stream> so long as L<Test::Stream::Legacy::Builder> was loaded,
however this implementation is significantly more efficient.

=item Test/Tester.pm -> Test/Stream/Legacy/Tester.pm

This is modified L<Test::Tester> code to make it support L<Test::Stream>. Using
this is actually discouraged in favor of L<Test::Stream::Tester>.

=item Test/Builder/Tester.pm -> Test/Stream/Legacy/Builder/Tester.pm

This is modified L<Test::Builder::Tester> code to make it support
L<Test::Stream>. Using this is actually discouraged in favor of
L<Test::Stream::Tester>.

=item (And a couple other minor ones)

Support modules for L<Test::Tester> and L<Test::Builder::Tester>.

=back

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

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

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

=cut
