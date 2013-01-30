use Module::Build;

Module::Build -> new
(
 module_name    => 'Module::Metadata::Changes',
 license        => 'artistic_2',
 dist_abstract  => "Manage a module's machine-readable CHANGES file",
 dist_author    => 'Ron Savage <ron@savage.net.au>',
 build_requires =>
 {
	 Test::More=> 0.96,
	 Test::Pod  => 1.45,
 },
 configure_requires =>
 {
 	 Module::Build => 0.3800,
 },
 requires =>
 {
	 Config::IniFiles            => 2.66,
	 DateTime                    => 0.66,
	 DateTime::Format::HTTP      => 0.40,
	 DateTime::Format::Strptime  => 1.5000,
	 DateTime::Format::W3CDTF    => 0.06,
	 Hash::FieldHash             => 0.10,
	 HTML::Entities::Interpolate => 1.03,
	 HTML::Template              => 2.9,
	 Perl6::Slurp                => 0.03,
	 version                     => 0.82,
 },
) -> create_build_script();

print "\a\n";
print "* Don't forget to install the CSS and *.tmpl files, which are \n";
print "* shipped in the htdocs/ directory within the distro, if you \n";
print "* wish to utilize the HTML output options of ini.report.pl. \n";
print "* Run ini.report.pl -h for details. \n";
print "\n";
