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
    if ($INC{'Test/Builder.pm'} && $INC{'Test/Builder.pm'} !~ m(/\Q$ALT_FILES{'Test/Builder.pm'}\E$)) {
        warn "Test/Builder.pm is already loaded, attempting to take over.\n";
        my $tb = {%{Test::Builder->new}};
        wipe_namespace($PACKAGE_MAP{'Test/Builder.pm'});
        load_alt('Test/Builder.pm');
        upgrade_to_stream($tb);
    }

    for my $file (keys %ALT_FILES) {
        next if $file eq 'Test/Builder.pm';    # Already Handled
        next unless $INC{$file};               # Not Loaded
        next if $INC{$file} !~ m(/\Q$ALT_FILES{$file}\E$);    # Loaded the right one
        warn "$file is already loaded, attempting to replace it.\n";

        wipe_namespace($PACKAGE_MAP{$file});
        load_alt($file);
    }
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
}

1;
