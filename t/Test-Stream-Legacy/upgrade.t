use strict;
use warnings;

use Test::More; # Original More and Builder.

# Get the singleton
my $TB = Test::Builder->new;

# Get initial OK
my $ok = __PACKAGE__->can('ok');
is($ok, Test::More->can('ok'), "original 'ok'");

# Make sure we loaded the right ones
like($INC{'Test/Builder.pm'}, qr{Test/Builder\.pm$}, "Loaded builder");
like($INC{'Test/More.pm'},    qr{Test/More\.pm}, "Loaded more");

# Do the upgrade!
my @warnings;
{
    local $SIG{__WARN__} = sub { push @warnings => @_ };
    require Test::Stream::Legacy;
    Test::Stream::Legacy->import;
}

# Verify state
is(Test::Stream->shared->count, 3, "Inherited state");

is_deeply(
    [ sort @warnings ],
    [
        "Test/Builder.pm is already loaded, attempting to replace it.\n",
        "Test/Builder/Module.pm is already loaded, attempting to replace it.\n",
        "Test/More.pm is already loaded, attempting to replace it.\n",
    ],
    "Got upgrade warnings"
);

# Verify new loaded files
like($INC{'Test/Builder.pm'}, qr{Test/Stream/Legacy/Builder\.pm$}, "Loaded legacy/builder");
like($INC{'Test/More.pm'},    qr{Test/Stream/More\.pm}, "Loaded stream/more");

# Check that things are all still fine.
is($TB, $Test::Builder::Test, "Same singleton instance");
is(__PACKAGE__->can('ok'), Test::Stream::More->can('ok'), "correct 'ok' function");
is(Test::Stream::More->can('ok'), Test::More->can('ok'), "Test::More 'ok' updated");
ok(__PACKAGE__->can('ok') != $ok, "updated the 'ok' function");

done_testing;
