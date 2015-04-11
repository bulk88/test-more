use strict;
use warnings;
use Test::Stream::Legacy;
use Test::Stream::More;

ok(!$INC{'Test/Builder.pm'}, "No Builder yet");
ok(!$INC{'Test/More.pm'}, "No More yet");
ok(!$INC{'Test/Simple.pm'}, "No Simple yet");

require Test::More;
require Test::Simple;

like($INC{'Test/Builder.pm'}, qr{Test/Stream/Legacy/Builder\.pm$}, "Loaded legacy/builder");
like($INC{'Test/More.pm'},    qr{Test/Stream/More\.pm}, "Loaded stream/more");
like($INC{'Test/Simple.pm'},  qr{Test/Stream/Simple\.pm}, "Loaded stream/simple");

done_testing;
