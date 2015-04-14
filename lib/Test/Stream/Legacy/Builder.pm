package Test::Stream::Legacy::Builder;
package
    Test::Builder;

use strict;
use warnings;

use Test::Stream;
use Test::Stream::Hub;
use Test::Stream::Toolset;
use Test::Stream::Context;
use Test::Stream::Carp qw/confess/;
use Test::Stream::Meta qw/MODERN/;

use Test::Stream::Util qw/try protect unoverload_str is_regex/;
use Scalar::Util qw/blessed reftype/;

use Test::Stream::More::Tools;

BEGIN {
    my $meta = Test::Stream::Meta->is_tester('main');
    Test::Stream->shared->set_use_legacy(1)
        unless $meta && $meta->{+MODERN};
}

# The mostly-singleton, and other package vars.
our $Test ||= Test::Builder->new;
our $_ORIG_Test = $Test;
our $Level = 1;

sub ctx {
    my $self = shift || die "No self in context";
    my ($add) = @_;
    my $ctx = Test::Stream::Context::context(2 + ($add || 0), $self->{hub});
    if (defined $self->{Todo}) {
        $ctx->set_in_todo(1);
        $ctx->set_todo($self->{Todo});
        $ctx->set_diag_todo(1);
    }
    return $ctx;
}

sub hub {
    my $self = shift;
    return $self->{hub} || Test::Stream->shared;
}

sub depth { $_[0]->{depth} || 0 }

# This is only for unit tests at this point.
sub _ending {
    my $self = shift;
    my ($ctx) = @_;
    return unless $self->{hub};
    require Test::Stream::ExitMagic;
    $self->{hub}->set_no_ending(0);
    Test::Stream::ExitMagic->new->do_magic($self->{hub}, $ctx);
}


####################
# {{{ Constructors #
####################

sub new {
    my $class  = shift;
    my %params = @_;
    $Test ||= $class->create(shared_hub => 1, init => 1);

    return $Test;
}

sub create {
    my $class  = shift;
    my %params = @_;

    my $self = bless {}, $class;
    $self->reset(%params);

    return $self;
}

# Copy an object, currently a shallow.
# This does *not* bless the destination.  This keeps the destructor from
# firing when we're just storing a copy of the object to restore later.
sub _copy {
    my ($src, $dest) = @_;
    %$dest = %$src;
    return;
}

####################
# }}} Constructors #
####################

#############################
# {{{ Children and subtests #
#############################

sub subtest {
    my $self = shift;
    my $ctx = $self->ctx();
    require Test::Stream::Subtest;
    return Test::Stream::Subtest::subtest(@_);
}

sub child {
    my( $self, $name ) = @_;

    my $ctx = $self->ctx;

    if ($self->{child}) {
        my $cname = $self->{child}->{Name};
        $ctx->throw("You already have a child named ($cname) running");
    }

    $name ||= "Child of " . $self->{Name};
    my $hub = $self->{hub} || Test::Stream->shared;
    $ctx->subtest_start($name, parent_todo => $ctx->in_todo);

    my $child = bless {
        %$self,
        '?' => $?,
        parent => $self,
    };

    $? = 0;
    $child->{Name} = $name;
    $self->{child} = $child;
    Scalar::Util::weaken($self->{child});

    return $child;
}

sub finalize {
    my $self = shift;

    return unless $self->{parent};

    my $ctx = $self->ctx;

    if ($self->{child}) {
        my $cname = $self->{child}->{Name};
        $ctx->throw("Can't call finalize() with child ($cname) active");
    }

    $self->_ending($ctx);
    my $passing = $ctx->hub->is_passing;
    my $count = $ctx->hub->count;
    my $name = $self->{Name};

    my $hub = $self->{hub} || Test::Stream->shared;

    my $parent = $self->parent;
    $self->{parent}->{child} = undef;
    $self->{parent} = undef;

    $? = $self->{'?'};

    my $st = $ctx->subtest_stop($name);

    $parent->ctx->send_event(
        'Subtest',
        name         => $st->{name},
        state        => $st->{state},
        events       => $st->{events},
        exception    => $st->{exception},
        early_return => $st->{early_return},
        delayed      => $st->{delayed},
        instant      => $st->{instant},
    );
}

sub in_subtest {
    my $self = shift;
    my $ctx = $self->ctx;
    return scalar @{$ctx->hub->subtests};
}

sub parent { $_[0]->{parent} }
sub name   { $_[0]->{Name} }

sub DESTROY {
    my $self = shift;
    return unless $self->{parent};
    return if $self->{Skip_All};
    $self->{parent}->is_passing(0);
    my $name = $self->{Name};
    die "Child ($name) exited without calling finalize()";
}

#############################
# }}} Children and subtests #
#############################

#####################################
# {{{ stuff for TODO status #
#####################################

sub find_TODO {
    my ($self, $pack, $set, $new_value) = @_;

    unless ($pack) {
        if (my $ctx = Test::Stream::Context->peek) {
            $pack = $ctx->package;
            my $old = $ctx->todo;
            $ctx->set_todo($new_value) if $set;
            return $old;
        }

        $pack = $self->exported_to || return;
    }

    no strict 'refs';    ## no critic
    no warnings 'once';
    my $old_value = ${$pack . '::TODO'};
    $set and ${$pack . '::TODO'} = $new_value;
    return $old_value;
}

sub todo {
    my ($self, $pack) = @_;

    return $self->{Todo} if defined $self->{Todo};

    my $ctx = $self->ctx;

    my $todo = $self->find_TODO($pack);
    return $todo if defined $todo;

    return '';
}

sub in_todo {
    my $self = shift;

    my $ctx = $self->ctx;
    return 1 if $ctx->in_todo;

    return (defined $self->{Todo} || $self->find_TODO) ? 1 : 0;
}

sub todo_start {
    my $self = shift;
    my $message = @_ ? shift : '';

    $self->{Start_Todo}++;
    if ($self->in_todo) {
        push @{$self->{Todo_Stack}} => $self->todo;
    }
    $self->{Todo} = $message;

    return;
}

sub todo_end {
    my $self = shift;

    if (!$self->{Start_Todo}) {
        $self->ctx(-1)->throw('todo_end() called without todo_start()');
    }

    $self->{Start_Todo}--;

    if ($self->{Start_Todo} && @{$self->{Todo_Stack}}) {
        $self->{Todo} = pop @{$self->{Todo_Stack}};
    }
    else {
        delete $self->{Todo};
    }

    return;
}

#####################################
# }}} Finding Testers and Providers #
#####################################

#####################################################
# {{{ Monkeypatching support
#####################################################

my %WARNED;
our ($CTX, %ORIG);
our %EVENTS = (
    Ok   => [qw/pass name/],
    Plan => [qw/max directive reason/],
    Diag => [qw/message/],
    Note => [qw/message/],
);
{
    no strict 'refs';
    %ORIG = map { $_ => \&{$_} } qw/ok note diag plan done_testing/;
}

sub WARN_OF_OVERRIDE {
    my ($sub, $ctx) = @_;

    return unless $ctx->modern;
    my $old = $ORIG{$sub};
    # Use package instead of self, we want replaced subs, not subclass overrides.
    my $new = __PACKAGE__->can($sub);

    return if $new == $old;

    require B;
    my $o    = B::svref_2object($new);
    my $gv   = $o->GV;
    my $st   = $o->START;
    my $name = $gv->NAME;
    my $pkg  = $gv->STASH->NAME;
    my $line = $st->line;
    my $file = $st->file;

    warn <<"    EOT" unless $WARNED{"$pkg $name $file $line"}++;

*******************************************************************************
Something monkeypatched Test::Builder::$sub()!
The new sub is '$pkg\::$name' defined in $file around line $line.
In the future monkeypatching Test::Builder::$sub() may no longer work as
expected.

Test::Stream now provides tools to properly hook into events so that
monkeypatching is no longer needed.
*******************************************************************************
    EOT
}

sub _set_monkeypatch_args {
    my $self = shift;
    confess "monkeypatch args already set!"
        if $self->{monkeypatch_args};
    ($self->{monkeypatch_args}) = @_;
}

sub _set_monkeypatch_event {
    my $self = shift;
    confess "monkeypatch event already set!"
        if $self->{monkeypatch_event};
    ($self->{monkeypatch_event}) = @_;
}

# These 2 methods delete the item before returning, this is to avoid
# contamination in later events.
sub _get_monkeypatch_args {
    my $self = shift;
    return delete $self->{monkeypatch_args};
}

sub _get_monkeypatch_event {
    my $self = shift;
    return delete $self->{monkeypatch_event};
}

sub monkeypatch_event {
    my $self = shift;
    my ($event, %args) = @_;

    my @ordered;

    if ($event eq 'Plan') {
        my $max = $args{max};
        my $dir = $args{directive};
        my $msg = $args{reason};

        $dir ||= 'tests';
        $dir = 'skip_all' if $dir eq 'SKIP';
        $dir = 'no_plan'  if $dir eq 'NO PLAN';

        @ordered = ($dir, $max || $msg || ());
    }
    else {
        my $fields = $EVENTS{$event};
        $self->_set_monkeypatch_args(\%args);
        @ordered = @args{@$fields};
    }

    my $meth = lc($event);
    $self->$meth(@ordered);
    return $self->_get_monkeypatch_event;
}

#####################################################
# }}} Monkeypatching support
#####################################################

################
# {{{ Planning #
################

my %PLAN_CMDS = (
    no_plan  => 'no_plan',
    skip_all => 'skip_all',
    tests    => '_plan_tests',
);

sub plan {
    my ($self, $cmd, @args) = @_;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();
    WARN_OF_OVERRIDE(plan => $ctx);

    return unless $cmd;

    if (my $method = $PLAN_CMDS{$cmd}) {
        $self->$method(@args);
    }
    else {
        my @in = grep { defined } ($cmd, @args);
        $self->ctx->throw("plan() doesn't understand @in");
    }

    return 1;
}

sub skip_all {
    my ($self, $reason) = @_;
    my $mp_args = $self->_get_monkeypatch_args;

    $self->{Skip_All} = 1;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();

    my $e = $ctx->build_event('Plan', $mp_args ? %$mp_args : (), max => 0, directive => 'SKIP', reason => $reason);
    $ctx->send($e);
    $self->_set_monkeypatch_event($e) if $mp_args;
}

sub no_plan {
    my ($self, @args) = @_;
    my $mp_args = $self->_get_monkeypatch_args;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();

    $ctx->alert("no_plan takes no arguments") if @args;
    my $e = $ctx->build_event('Plan', $mp_args ? %$mp_args : (), max => 0, directive => 'NO PLAN');
    $ctx->send($e);
    $self->_set_monkeypatch_event($e) if $mp_args;

    return 1;
}

sub _plan_tests {
    my ($self, $arg) = @_;
    my $mp_args = $self->_get_monkeypatch_args;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();

    if ($arg) {
        $ctx->throw("Number of tests must be a positive integer.  You gave it '$arg'")
            unless $arg =~ /^\+?\d+$/;

        my $e = $ctx->build_event('Plan', $mp_args ? %$mp_args : (), max => $arg);
        $ctx->send($e);
        $self->_set_monkeypatch_event($e) if $mp_args;
    }
    elsif (!defined $arg) {
        $ctx->throw("Got an undefined number of tests");
    }
    else {
        $ctx->throw("You said to run 0 tests");
    }

    return;
}

sub done_testing {
    my ($self, $num_tests) = @_;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();
    WARN_OF_OVERRIDE(done_testing => $ctx);

    my $out = $ctx->hub->done_testing($ctx, $num_tests);
    return $out;
}

################
# }}} Planning #
################

#############################
# {{{ Base Event Producers #
#############################

sub ok {
    my $self = shift;
    my ($test, $name) = @_;
    my $mp_args = $self->_get_monkeypatch_args;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();
    WARN_OF_OVERRIDE(ok => $ctx);

    if ($self->{child}) {
        $self->is_passing(0);
        $ctx->throw("Cannot run test ($name) with active children");
    }

    my $e = $ctx->build_event('Ok', $mp_args ? %$mp_args : (), pass => $test, name => $name);
    $ctx->send($e);
    $self->_set_monkeypatch_event($e, $mp_args) if $mp_args;
    return $test ? 1 : 0;
}

sub BAIL_OUT {
    my( $self, $reason ) = @_;
    $self->ctx()->bail($reason);
}

sub skip {
    my( $self, $why ) = @_;
    $why ||= '';
    unoverload_str( \$why );

    my $ctx = $self->ctx();
    $ctx->set_skip($why);
    $ctx->ok(1, '');
    $ctx->set_skip(undef);
}

sub todo_skip {
    my( $self, $why ) = @_;
    $why ||= '';
    unoverload_str( \$why );

    my $ctx = $self->ctx();
    $ctx->set_skip($why);
    $ctx->set_todo($why);
    $ctx->ok(0, '');
    $ctx->set_skip(undef);
    $ctx->set_todo(undef);
}

sub diag {
    my $self    = shift;
    my $msg     = join '', map { defined($_) ? $_ : 'undef' } @_;
    my $mp_args = $self->_get_monkeypatch_args;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();
    WARN_OF_OVERRIDE(diag => $ctx);

    my $e = $ctx->build_event('Diag', $mp_args ? %$mp_args : (), message => $msg);
    $ctx->send($e);
    $self->_set_monkeypatch_event($e) if $mp_args;
    return;
}

sub note {
    my $self    = shift;
    my $msg     = join '', map { defined($_) ? $_ : 'undef' } @_;
    my $mp_args = $self->_get_monkeypatch_args;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();
    WARN_OF_OVERRIDE(note => $ctx);

    my $e = $ctx->build_event('Note', $mp_args ? %$mp_args : (), message => $msg);
    $ctx->send($e);
    $self->_set_monkeypatch_event($e) if $mp_args;
    return;
}

#############################
# }}} Base Event Producers #
#############################

#######################
# {{{ Public helpers #
#######################

sub explain {
    my $self = shift;

    return map {
        ref $_
          ? do {
            protect { require Data::Dumper };
            my $dumper = Data::Dumper->new( [$_] );
            $dumper->Indent(1)->Terse(1);
            $dumper->Sortkeys(1) if $dumper->can("Sortkeys");
            $dumper->Dump;
          }
          : $_
    } @_;
}

sub carp {
    my $self = shift;
    $self->ctx->alert(join '' => @_);
}

sub croak {
    my $self = shift;
    $self->ctx->throw(join '' => @_);
}

sub has_plan {
    my $self = shift;

    my $plan = $self->ctx->hub->plan || return undef;
    return 'no_plan' if $plan->directive && $plan->directive eq 'NO PLAN';
    return $plan->max;
}

sub reset {
    my $self = shift;
    my %params = @_;

    $self->{use_shared} = 1 if $params{shared_hub};

    if ($self->{use_shared}) {
        Test::Stream->shared->_reset unless $params{init};
        Test::Stream->shared->state->set_legacy([]);
    }
    else {
        $self->{hub} = Test::Stream::Hub->new();
        $self->{hub}->set_use_legacy(1);
        $self->{hub}->state->set_legacy([]);
        $self->{stream} = $self->{hub}; # Test::SharedFork shim
    }

    # We leave this a global because it has to be localized and localizing
    # hash keys is just asking for pain.  Also, it was documented.
    $Level = 1;

    $self->{Name} = $0;

    $self->{Original_Pid} = $$;
    $self->{Child_Name}   = undef;

    $self->{Exported_To} = undef;

    $self->{Todo}               = undef;
    $self->{Todo_Stack}         = [];
    $self->{Start_Todo}         = 0;
    $self->{Opened_Testhandles} = 0;

    return;
}

#######################
# }}} Public helpers #
#######################

#################################
# {{{ Advanced Event Producers #
#################################

sub cmp_ok {
    my( $self, $got, $type, $expect, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->cmp_check($got, $type, $expect);
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub is_eq {
    my( $self, $got, $expect, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->is_eq($got, $expect);
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub is_num {
    my( $self, $got, $expect, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->is_num($got, $expect);
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub isnt_eq {
    my( $self, $got, $dont_expect, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->isnt_eq($got, $dont_expect);
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub isnt_num {
    my( $self, $got, $dont_expect, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->isnt_num($got, $dont_expect);
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub like {
    my( $self, $thing, $regex, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->regex_check($thing, $regex, '=~');
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub unlike {
    my( $self, $thing, $regex, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->regex_check($thing, $regex, '!~');
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

#################################
# }}} Advanced Event Producers #
#################################

################################################
# {{{ Misc #
################################################

sub _new_fh {
    my $self = shift;
    my($file_or_fh) = shift;

    return $file_or_fh if $self->is_fh($file_or_fh);

    my $fh;
    if( ref $file_or_fh eq 'SCALAR' ) {
        open $fh, ">>", $file_or_fh
          or croak("Can't open scalar ref $file_or_fh: $!");
    }
    else {
        open $fh, ">", $file_or_fh
          or croak("Can't open test output log $file_or_fh: $!");
        Test::Stream::IOSets->_autoflush($fh);
    }

    return $fh;
}

sub output {
    my $self = shift;
    my $handles = $self->ctx->hub->io_sets->init_encoding('legacy');
    $handles->[0] = $self->_new_fh(@_) if @_;
    return $handles->[0];
}

sub failure_output {
    my $self = shift;
    my $handles = $self->ctx->hub->io_sets->init_encoding('legacy');
    $handles->[1] = $self->_new_fh(@_) if @_;
    return $handles->[1];
}

sub todo_output {
    my $self = shift;
    my $handles = $self->ctx->hub->io_sets->init_encoding('legacy');
    $handles->[2] = $self->_new_fh(@_) if @_;
    return $handles->[2] || $handles->[0];
}

sub reset_outputs {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->io_sets->reset_legacy;
}

sub use_numbers {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->set_use_numbers(@_) if @_;
    $ctx->hub->use_numbers;
}

sub no_ending {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->set_no_ending(@_) if @_;
    $ctx->hub->no_ending || 0;
}

sub no_header {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->set_no_header(@_) if @_;
    $ctx->hub->no_header || 0;
}

sub no_diag {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->set_no_diag(@_) if @_;
    $ctx->hub->no_diag || 0;
}

sub exported_to {
    my($self, $pack) = @_;
    $self->{Exported_To} = $pack if defined $pack;
    return $self->{Exported_To};
}

sub is_fh {
    my $self     = shift;
    my $maybe_fh = shift;
    return 0 unless defined $maybe_fh;

    return 1 if ref $maybe_fh  eq 'GLOB';    # its a glob ref
    return 1 if ref \$maybe_fh eq 'GLOB';    # its a glob

    my $out;
    protect {
        $out = eval { $maybe_fh->isa("IO::Handle") }
            || eval { tied($maybe_fh)->can('TIEHANDLE') };
    };

    return $out;
}

sub BAILOUT { goto &BAIL_OUT }

sub expected_tests {
    my $self = shift;

    my $ctx = $self->ctx;
    $ctx->plan(@_) if @_;

    my $plan = $ctx->hub->plan || return 0;
    return $plan->max || 0;
}

sub caller {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    my $self = shift;

    my $ctx = $self->ctx;

    return wantarray ? $ctx->call : $ctx->package;
}

sub level {
    my( $self, $level ) = @_;
    $Level = $level if defined $level;
    return $Level;
}

sub maybe_regex {
    my ($self, $regex) = @_;
    return is_regex($regex);
}

sub is_passing {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->is_passing(@_);
}

# Yeah, this is not efficient, but it is only legacy support, barely anything
# uses it, and they really should not.
sub current_test {
    my $self = shift;

    my $ctx = $self->ctx;

    if (@_) {
        my ($num) = @_;
        my $state = $ctx->hub->state;
        $state->set_count($num);

        my $old = $state->legacy || [];
        my $new = [];

        my $nctx = $ctx->snapshot;
        $nctx->set_todo('incrementing test number');
        $nctx->set_in_todo(1);

        for (1 .. $num) {
            my $i;
            $i = shift @$old while @$old && (!$i || !$i->isa('Test::Stream::Event::Ok'));
            $i ||= Test::Stream::Event::Ok->new(
                context        => $nctx,
                created        => [CORE::caller()],
                in_subtest     => 0,
                effective_pass => 1,
            );

            push @$new => $i;
        }

        $state->set_legacy($new);
    }

    $ctx->hub->count;
}

sub details {
    my $self = shift;
    my $ctx = $self->ctx;
    my $state = $ctx->hub->state;
    my @out;
    my $legacy = $state->legacy;
    return @out unless $legacy;

    for my $e (@$legacy) {
        next unless $e && $e->isa('Test::Stream::Event::Ok');
        push @out => $e->to_legacy;
    }

    return @out;
}

sub summary {
    my $self = shift;
    my $ctx = $self->ctx;
    my $state = $ctx->hub->state;
    my $legacy = $state->legacy;
    return @{[]} unless $legacy;
    return map { $_->isa('Test::Stream::Event::Ok') ? ($_->effective_pass ? 1 : 0) : ()} @$legacy;
}

###################################
# }}} Misc #
###################################

####################
# {{{ TB1.5 stuff  #
####################

# This is just a list of method Test::Builder current does not have that Test::Builder 1.5 does.
my %TB15_METHODS = map { $_ => 1 } qw{
    _file_and_line _join_message _make_default _my_exit _reset_todo_state
    _result_to_hash _results _todo_state formatter history in_test
    no_change_exit_code post_event post_result set_formatter set_plan test_end
    test_exit_code test_start test_state
};

our $AUTOLOAD;

sub AUTOLOAD {
    $AUTOLOAD =~ m/^(.*)::([^:]+)$/;
    my ($package, $sub) = ($1, $2);

    my @caller = CORE::caller();
    my $msg    = qq{Can't locate object method "$sub" via package "$package" at $caller[1] line $caller[2].\n};

    $msg .= <<"    EOT" if $TB15_METHODS{$sub};

    *************************************************************************
    '$sub' is a Test::Builder 1.5 method. Test::Builder 1.5 is a dead branch.
    You need to update your code so that it no longer treats Test::Builders
    over a specific version number as anything special.

    See: http://blogs.perl.org/users/chad_exodist_granum/2014/03/testmore---new-maintainer-also-stop-version-checking.html
    *************************************************************************
    EOT

    die $msg;
}

####################
# }}} TB1.5 stuff  #
####################

##################################
# {{{ Legacy support, do not use #
##################################

# These are here to support old versions of Test::More which may be bundled
# with some dists. See https://github.com/Test-More/test-more/issues/479

sub _try {
    my( $self, $code, %opts ) = @_;

    my $error;
    my $return;
    protect {
        $return = eval { $code->() };
        $error = $@;
    };

    die $error if $error and $opts{die_on_fail};

    return wantarray ? ( $return, $error ) : $return;
}

sub _unoverload {
    my $self = shift;
    my $type = shift;

    $self->_try(sub { require overload; }, die_on_fail => 1);

    foreach my $thing (@_) {
        if( $self->_is_object($$thing) ) {
            if( my $string_meth = overload::Method( $$thing, $type ) ) {
                $$thing = $$thing->$string_meth();
            }
        }
    }

    return;
}

sub _is_object {
    my( $self, $thing ) = @_;

    return $self->_try( sub { ref $thing && $thing->isa('UNIVERSAL') } ) ? 1 : 0;
}

sub _unoverload_str {
    my $self = shift;

    return $self->_unoverload( q[""], @_ );
}

sub _unoverload_num {
    my $self = shift;

    $self->_unoverload( '0+', @_ );

    for my $val (@_) {
        next unless $self->_is_dualvar($$val);
        $$val = $$val + 0;
    }

    return;
}

# This is a hack to detect a dualvar such as $!
sub _is_dualvar {
    my( $self, $val ) = @_;

    # Objects are not dualvars.
    return 0 if ref $val;

    no warnings 'numeric';
    my $numval = $val + 0;
    return ($numval != 0 and $numval ne $val ? 1 : 0);
}

##################################
# }}} Legacy support, do not use #
##################################


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Legacy::Builder - Compatability fork of Test::Builder.

=head1 DESCRIPTION

This is a compatability fork of L<Test::Builder>. This module fully implements
the L<Test::Builder> API. This module exists to support legacy modules, please
do not use it to write new things.

=head1 SEE ALSO

See L<Test::Builder> for the actual documentation for using this module.

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
