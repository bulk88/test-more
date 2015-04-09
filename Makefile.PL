#!/usr/bin/perl -w

use 5.008001;

use Config;
use ExtUtils::MakeMaker;

my $PACKAGE = 'Test::Stream';
($PACKAGE_FILE = $PACKAGE) =~ s|::|/|g;

eval "require $PACKAGE";
my $PACKAGE_VERSION = ${$PACKAGE.'::VERSION'};

my $mm_ver = $ExtUtils::MakeMaker::VERSION;
if ($mm_ver =~ /_/) { # dev version
    $mm_ver = eval $mm_ver;
    die $@ if $@;
}


# Windows does not expand *.t and MakeMaker only started working around
# that for TESTS in 6.27.  This does not introduce a circular dep
# because MakeMaker ships with its own Test::More.
my %Prereqs;
$Prereqs{'ExtUtils::MakeMaker'} = 6.27 if $^O eq 'MSWin32';

my $install_dir = $] >= 5.006002 && $] < 5.012000 ? 'perl' : 'site';

WriteMakefile(
    NAME            => $PACKAGE,

    VERSION_FROM    => "lib/$PACKAGE_FILE.pm",
    ABSTRACT_FROM   => "lib/$PACKAGE_FILE.pm",
    AUTHOR          => 'Chad Granum <exodist7@gmail.com>',

    ($mm_ver >= 6.31 ? (LICENSE => 'perl') : ()),

    PREREQ_PM       => { 
        'Test::Harness'         => 2.03,
        'Scalar::Util'          => 1.13,
        %Prereqs
    },

    INSTALLDIRS => $install_dir,
    test => { RECURSIVE_TEST_FILES => 1 },

    ($mm_ver < 6.48 ? () : (MIN_PERL_VERSION => 5.008001)),

    ($mm_ver < 6.46 ? () : (META_MERGE => {
        resources => {
            license     =>      'http://dev.perl.org/licenses/',
            homepage    =>      'http://github.com/Test-More/test-more/',
            bugtracker  =>      'http://github.com/Test-More/test-more/issues/',
            repository  =>      'http://github.com/Test-More/test-more/',
            MailingList =>      'http://lists.perl.org/list/perl-qa.html',
        },
    }))
);


{
    package MY;


    sub postamble {
        return <<'MAKE';

perltidy:
	find . -name '*.pm' | xargs perltidy -b
	find . -name '*.pm.bak' | xargs rm

MAKE
    }


    # Test with multiple versions of perl before releasing
    sub dist_test {
        my $self = shift;

        my $make = $self->SUPER::dist_test(@_);
        return $make unless $ENV{AUTHOR_TESTING} and $ENV{AUTHOR_TESTING} eq 'MSCHWERN';

        # Strip off all the whitespace at the end, we'll put our own in.
        $make =~ s{\s+\z}{\n};

        my @perls = qw(
            perl5.20.0
            perl5.18.2
            perl5.16.3
            perl5.14.4
            perl5.12.5
            perl5.10.1
            perl5.8.9
        );

        for my $perl (@perls) {
            if( !`which $perl` ) {
                print STDERR "Missing $perl";
                next;
            }
            $make .= sprintf <<'END', $perl;
	cd $(DISTVNAME) && $(MAKE) clean && %s Makefile.PL && PERL_RELEASING=0 $(MAKE) test $(PASTHRU)
END
        }

        # Rebuild so subsequent make commands work
        $make .= <<'END';
	$(MAKE) realclean
	$(FULLPERLRUN) Makefile.PL
	$(MAKE)
END

        $make .= "\n";

        return $make;
    }
}
