use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile
(
 ($] ge '5.005') ?
 (
  AUTHOR   => 'Ron Savage (ron@savage.net.au)',
  ABSTRACT => "Manage a module's CHANGES file",
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
 PL_FILES  => {},
 PREREQ_PM =>
 {
	 Config::IniFiles            => 2.66,
	 DateTime                    => 0.66,
	 DateTime::Format::HTTP      => 0.40,
	 DateTime::Format::Strptime  => 1.5000,
	 DateTime::Format::W3CDTF    => 0.06,
	 HTML::Entities::Interpolate => 1.03,
	 HTML::Template              => 2.9,
	 Perl6::Slurp                => 0.03,
	 Test::More                  => 0.96,
	 Test::Pod                   => 1.41,
	 version                     => 0.82,
 },
 VERSION_FROM => 'lib/Module/Metadata/Changes.pm',
);

print "\a\n";
print "* Don't forget to install the CSS and *.tmpl files, which are \n";
print "* shipped in the htdocs/ directory within the distro, if you \n";
print "* wish to utilize the HTML output options of ini.report.pl. \n";
print "* Run ini.report.pl -h for details. \n";
print "\n";
