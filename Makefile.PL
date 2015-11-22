use ExtUtils::MakeMaker;

# ----------------

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile
(
	($] ge '5.005') ?
	(
		AUTHOR   => 'Ron Savage (ron@savage.net.au)',
		ABSTRACT => "Manage a module's machine-readable Changes/CHANGES file",
	) : (),
	clean =>
	{
		FILES => 'blib/* Makefile MANIFEST Module-Metadata-Changes-*'
	},
	dist =>
	{
		COMPRESS => 'gzip',
		SUFFIX   => 'gz'
},
	DISTNAME  => 'Module-Metadata-Changes',
	NAME      => 'Module::Metadata::Changes',
	LICENSE   => 'artistic_2',
	PL_FILES  => {},
	PREREQ_PM =>
	{
		'Config::IniFiles' => 2.88,
		'DateTime' => 0.66,
		'DateTime::Format::HTTP' => 0.42,
		'DateTime::Format::Strptime' => 1.61,
		'DateTime::Format::W3CDTF' => 0.06,
		'File::Slurper' => 0.008,
		'HTML::Entities::Interpolate' => 1.06,
		'HTML::Template' => 2.95,
		'Moo' => 2.000002,
		'Test::Stream' => 1.302026,
		'Test::Pod' => 1.48,
		'Type::Tiny' => 1.000005,
		'version' => 0,
	},
	VERSION_FROM => 'lib/Module/Metadata/Changes.pm',
);

print "\a\n";
print "* Don't forget to install the CSS and *.tmpl files, which are \n";
print "* shipped in the htdocs/ directory within the distro, if you \n";
print "* wish to utilize the HTML output options of ini.report.pl. \n";
print "* Run ini.report.pl -h for details. \n";
print "\n";
