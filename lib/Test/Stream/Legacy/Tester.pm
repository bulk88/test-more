use strict;

package Test::Stream::Legacy::Tester;
package
    Test::Tester;

use Test::Stream;
use Test::Stream::Legacy;
use Test::Builder;
use Test::Stream::Toolset;
use Test::Stream::More::Tools;
use Test::Tester::Capture;

require Exporter;

use vars qw( @ISA @EXPORT $VERSION );

our $VERSION = '1.301001_101';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

@EXPORT  = qw( run_tests check_tests check_test cmp_results show_space );
@ISA     = qw( Exporter );

my $want_space = $ENV{TESTTESTERSPACE};

sub show_space {
    $want_space = 1;
}

my $colour = '';
my $reset  = '';

if (my $want_colour = $ENV{TESTTESTERCOLOUR} || $ENV{TESTTESTERCOLOUR}) {
    if (eval "require Term::ANSIColor") {
        my ($f, $b) = split(",", $want_colour);
        $colour = Term::ANSIColor::color($f) . Term::ANSIColor::color("on_$b");
        $reset  = Term::ANSIColor::color("reset");
    }

}

my $capture = Test::Tester::Capture->new;
sub capture { $capture }

sub find_depth {
    my ($start, $end);
    my $l = 1;
    while (my @call = caller($l++)) {
        $start = $l if $call[3] =~ m/^Test::Builder::(ok|skip|todo_skip)$/;
        next unless $start;
        next unless $call[3] eq 'Test::Tester::run_tests';
        $end = $l;
        last;
    }

    return $Test::Builder::Level + 1 unless defined $start && defined $end;
    # 2 the eval and the anon sub
    return $end - $start - 2;
}

require Test::Stream::Event::Ok;
my $META = Test::Stream::HashBase::Meta->get('Test::Stream::Event::Ok');
my $idx = 'Test::Tester';

sub run_tests {
    my $test = shift;

    my $chub;
    if ($capture) {
        $chub = $capture->{hub};
    }

    my ($hub, $old) = Test::Stream->intercept_start($chub);
    $hub->set_use_legacy(1);
    $hub->states->[-1] = Test::Stream::State->new;
    $hub->munge(sub {
        my ($hub, $e) = @_;
        $e->{$idx} = find_depth() - $Test::Builder::Level;
        $e->{"${idx}_level"} = $Test::Builder::Level;
        require Carp;
        $e->{"${idx}_trace"} = Carp::longmess();
    });

    my $level = $Test::Builder::Level;

    my @out;
    my $prem = "";

    my $ok = eval {
        $test->();

        for my $e (@{$hub->legacy}) {
            if ($e->isa('Test::Stream::Event::Ok')) {
                push @out => $e->to_legacy;
                $out[-1]->{name} = '' unless defined $out[-1]->{name};
                $out[-1]->{diag} ||= "";
                $out[-1]->{depth} = $e->{$idx};
                for my $d (@{$e->diag || []}) {
                    next if $d->message =~ m{Failed (\(TODO\) )?test (.*\n\s*)?at .* line \d+\.};
                    next if $d->message =~ m{You named your test '.*'\.  You shouldn't use numbers for your test names};
                    chomp(my $msg = $d->message);
                    $msg .= "\n";
                    $out[-1]->{diag} .= $msg;
                }
            }
            elsif ($e->isa('Test::Stream::Event::Diag')) {
                chomp(my $msg = $e->message);
                $msg .= "\n";
                if (!@out) {
                    $prem .= $msg;
                    next;
                }
                next if $msg =~ m{Failed test .*\n\s*at .* line \d+\.};
                $out[-1]->{diag} .= $msg;
            }
        }

        1;
    };
    my $err = $@;

    $hub->states->[-1] = Test::Stream::State->new;

    Test::Stream->intercept_stop($hub);

    die $err unless $ok;

    return ($prem, @out);
}

sub check_test {
    my $test   = shift;
    my $expect = shift;
    my $name   = shift;
    $name = "" unless defined($name);

    @_ = ($test, [$expect], $name);
    goto &check_tests;
}

sub check_tests {
    my $test    = shift;
    my $expects = shift;
    my $name    = shift;
    $name = "" unless defined($name);

    my ($prem, @results) = eval { run_tests($test, $name) };

    my $ctx = context();

    my $ok = !$@;
    $ctx->ok($ok, "Test '$name' completed");
    $ctx->diag($@) unless $ok;

    $ok = !length($prem);
    $ctx->ok($ok, "Test '$name' no premature diagnostication");
    $ctx->diag("Before any testing anything, your tests said\n$prem") unless $ok;

    cmp_results(\@results, $expects, $name);
    return ($prem, @results);
}

sub cmp_field {
    my ($result, $expect, $field, $desc) = @_;

    my $ctx = context();
    if (defined $expect->{$field}) {
        my ($ok, @diag) = Test::Stream::More::Tools->is_eq(
            $result->{$field},
            $expect->{$field},
        );
        $ctx->ok($ok, "$desc compare $field");
    }
}

sub cmp_result {
    my ($result, $expect, $name) = @_;

    my $ctx = context();

    my $sub_name = $result->{name};
    $sub_name = "" unless defined($name);

    my $desc = "subtest '$sub_name' of '$name'";

    {
        cmp_field($result, $expect, "ok", $desc);

        cmp_field($result, $expect, "actual_ok", $desc);

        cmp_field($result, $expect, "type", $desc);

        cmp_field($result, $expect, "reason", $desc);

        cmp_field($result, $expect, "name", $desc);
    }

    # if we got no depth then default to 1
    my $depth = 1;
    if (exists $expect->{depth}) {
        $depth = $expect->{depth};
    }

    # if depth was explicitly undef then don't test it
    if (defined $depth) {
        $ctx->ok(1, "depth checking is deprecated, dummy pass result...");
    }

    if (defined(my $exp = $expect->{diag})) {
        # if there actually is some diag then put a \n on the end if it's not
        # there already

        $exp .= "\n" if (length($exp) and $exp !~ /\n$/);
        my $ok = $result->{diag} eq $exp;
        $ctx->ok(
            $ok,
            "subtest '$sub_name' of '$name' compare diag"
        );
        unless($ok) {
            my $got  = $result->{diag};
            my $glen = length($got);
            my $elen = length($exp);
            for ($got, $exp) {
                my @lines = split("\n", $_);
                $_ = join(
                    "\n",
                    map {
                        if ($want_space) {
                            $_ = $colour . escape($_) . $reset;
                        }
                        else {
                            "'$colour$_$reset'";
                        }
                    } @lines
                );
            }

            $ctx->diag(<<EOM);
Got diag ($glen bytes):
$got
Expected diag ($elen bytes):
$exp
EOM

        }
    }
}

sub escape {
    my $str = shift;
    my $res = '';
    for my $char (split("", $str)) {
        my $c = ord($char);
        if (($c > 32 and $c < 125) or $c == 10) {
            $res .= $char;
        }
        else {
            $res .= sprintf('\x{%x}', $c);
        }
    }
    return $res;
}

sub cmp_results {
    my ($results, $expects, $name) = @_;

    my $ctx = context();

    my ($ok, @diag) = Test::Stream::More::Tools->is_num(scalar @$results, scalar @$expects, "Test '$name' result count");
    $ctx->ok($ok, @diag);

    for (my $i = 0; $i < @$expects; $i++) {
        my $expect = $expects->[$i];
        my $result = $results->[$i];

        cmp_result($result, $expect, $name);
    }
}

######## nicked from Test::Stream::More
sub import {
    my $class = shift;
    my @plan = @_;

    my $caller = caller;
    my $ctx = context();

    my @imports = ();
    foreach my $idx (0 .. $#plan) {
        if ($plan[$idx] eq 'import') {
            my ($tag, $imports) = splice @plan, $idx, 2;
            @imports = @$imports;
            last;
        }
    }

    my ($directive, $arg) = @plan;
    if ($directive eq 'tests') {
        $ctx->plan($arg);
    }
    elsif ($directive) {
        $ctx->plan(0, $directive, $arg);
    }

    $class->_export_to_level(1, __PACKAGE__, @imports);
}

sub _export_to_level {
    my $pkg   = shift;
    my $level = shift;
    (undef) = shift;    # redundant arg
    my $callpkg = caller($level);
    $pkg->export($callpkg, @_);
}

############

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Legacy::Tester - Compatability fork of Test::Tester.

=head1 DESCRIPTION

This is a compatability fork of L<Test::Tester>. This module fully implements
the L<Test::Tester> API. This module exists to support legacy modules, please
do not use it to write new things.

=head1 SEE ALSO

See L<Test::Tester> for the actual documentation for using this module.

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
