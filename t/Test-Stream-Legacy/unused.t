use strict;
use warnings;
use Test::Stream::Legacy;
use Test::Stream::More;

ok(!$INC{'Test/Builder.pm'}, "No Builder yet");
ok(!$INC{'Test/More.pm'}, "No More yet");
ok(!$INC{'Test/Simple.pm'}, "No Simple yet");

done_testing;
