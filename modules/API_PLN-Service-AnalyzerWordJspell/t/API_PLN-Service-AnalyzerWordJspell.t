# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl API_PLN-Service-AnalyzerWordJspell.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('API_PLN::Service::AnalyzerWordJspell') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

