use Module::Build;

Module::Build -> new
(
 module_name    => 'Module::Metadata::Changes',
 license        => 'artistic',
 dist_abstract  => "Manage a module's CHANGES file",
 dist_author    => 'Ron Savage <ron@savage.net.au>',
 build_requires =>
 {
	 Test::More => 0,
	 Test::Pod  => 0,
 },
 requires =>
 {
	 Carp                        => 0,
	 Config::IniFiles            => 0,
	 DateTime                    => 0.42,
	 DateTime::Format::HTTP      => 0,
	 DateTime::Format::Strptime  => 0,
	 DateTime::Format::W3CDTF    => 0,
	 File::HomeDir               => 0,
	 HTML::Entities::Interpolate => 0,
	 HTML::Template              => 0,
	 Test::More                  => 0,
	 Test::Pod                   => 0,
	 version                     => 0,
 },
) -> create_build_script();

print "\a\n";
print "* Don't forget to install the CSS and *.tmpl files, which are \n";
print "* shipped in the htdocs/ directory within the distro, if you \n";
print "* wish to utilize the HTML output options of ini.report.pl. \n";
print "* Run ini.report.pl -h for details. \n";
print "\n";
