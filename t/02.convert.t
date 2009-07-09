use Test::More tests => 7;

BEGIN {chdir 't' if -d 't'}
use lib '../lib';

use Module::Metadata::Changes;

# ----------------------------

my($config) = Module::Metadata::Changes -> new({verbose => 0});

isa_ok($config, 'Module::Metadata::Changes', 'Result of new()');
is(-e './Non.standard.name', 1, './Non.standard.name file exists before conversion');

# Override the default file name to be converted: CHANGES.
# Convert ./Non.standard.name to ./Changelog.ini.

my($result) = $config -> convert('./Non.standard.name');

isa_ok($result, 'Module::Metadata::Changes', 'Result of convert()');
is(-e './Changelog.ini', 1, './Changelog.ini exists after conversion');

# Read ./Changelog.ini back in.

$result = $config -> read();

isa_ok($result, 'Module::Metadata::Changes', 'Resuult of read()');

my($release) = $config -> get_latest_release();
my($expect)  = '4.30';

is($config -> get_latest_version(), $expect, "Version of latest revision is $expect");

$expect = '2008-04-25T00:00:00';

is($$release{'Date'}, $expect, "Date of latest revision is $expect");
