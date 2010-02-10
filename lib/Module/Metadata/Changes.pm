package Module::Metadata::Changes;

use strict;
use warnings;

require 5.005_62;

require Exporter;

use Carp;

use Config::IniFiles;

use DateTime::Format::W3CDTF;

use File::HomeDir;

use HTML::Entities::Interpolate;
use HTML::Template;

use version;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Module::Metadata::Changes ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

our $VERSION = '1.07';

# ------------------------------------------------

# Encapsulated class data.

{
	my(%_attr_data) =
	(
	 _convert     => 0,
	 _inFileName  => '',
	 _outFileName => '',
	 _pathForHTML => '',
	 _release     => '',
	 _table       => 0,
	 _urlForCSS   => '/assets/css/module/metadata/changes/ini.css',
	 _verbose     => 0,
	 _webPage     => 0,
	);

	sub _default_for
	{
		my($self, $attr_name) = @_;

		$_attr_data{$attr_name};
	}

	sub _standard_keys
	{
		keys %_attr_data;
	}
}

#  -----------------------------------------------

sub convert
{
	my($self, $input_file_name) = @_;
	$input_file_name            ||= 'CHANGES';

	if (! -e $input_file_name)
	{
		Carp::croak "Error: No such file: $input_file_name";
	}

	if ($$self{'_verbose'})
	{
		$self -> log("Input file: $input_file_name");
	}

	open(INX, $input_file_name) || Carp::croak "Can't open($input_file_name): $!";
	my(@line) = <INX>;
	close INX;
	chomp @line;

	# Get module name from the first line.
	# 1st guess at format: Revision history for Perl extension Local::Wine.

	my($line)        = shift @line;
	$line            =~ s/\s+$//;
	$line            =~ s/\.$//;
	my(@field)       = split(/\s+/, $line);
	my($module_name) = $field[$#field];

	# 2nd guess at format: X::Y somewhere in the first line. This overrides the first guess.

	@field = split(/\s+/, $line);

	my($field);

	for $field (@field)
	{
		if ($field =~ /^.+::.+$/)
		{
			$module_name = $field;

			last;
		}
	}

	$$self{'config'} = Config::IniFiles -> new();

	$$self{'config'} -> AddSection('Module');
	$$self{'config'} -> newval('Module', 'Name', $module_name);
	$$self{'config'} -> newval('Module', 'Changelog.Creator', __PACKAGE__ . " V $VERSION");
	$$self{'config'} -> newval('Module', 'Changelog.Parser', "Config::IniFiles V $Config::IniFiles::VERSION");
	$self -> convert_body(@line) ;

	# Return object for method chaining.

	return $self -> write($$self{'_outFileName'});

} # End of convert.

#  -----------------------------------------------

sub convert_body
{
	my($self, @line) = @_;

	my($current_version, $current_date, @comment);
	my($date);
	my(@field);
	my($line);
	my($release, @release);
	my($version);

	for $line (@line)
	{
		$line  =~ s/^\s+//;
		$line  =~ s/\s+$//;

		next if (length($line) == 0);
		next if ($line =~ /^#/);

		# Try to get the version number and date.
		# Each release is expected to start with:
		# o 1.05  Fri Jan 25 10:08:00 2008
		# o 4.30 - Friday, April 25, 2008
		# o 4.08 - Thursday, March 15th, 2006

		$line  =~ tr/ / /s;
		$line  =~ s/,//g;
		@field = split(/\s(?:-\s)?/, $line, 2);

		# The "" keep version happy.

		eval{no warnings; $version  = version -> new("$field[0]");};

		$date = $self -> parse_datetime($field[1]);

		if ( ($version eq '0') || ($date eq 'Could not parse date') || ($date =~ /No input string/) )
		{
			# We got an error. So assume it's commentary on the current release.
			# If the line starts with EOT, jam a '-' in front of it to eascape it,
			# since Config::IniFiles uses EOT to terminate multi-line comments.

			$line = ".$line" if (substr($line, 0, 3) eq 'EOT');

			push @comment, $line;
		}
		else
		{
			# We got a version and a date. Assume it's a new release.
			# Step 1: Wrap up the last version, if any.

			if ($$self{'_verbose'} && $version && $date)
			{
				$self -> log("Processing: V $version $date");
			}

			if ($current_version)
			{
				$release = {Version => $current_version, Date => $current_date, Comments => [@comment]};

				push @release, $release;
			}

			# Step 2: Start the new version.

			if ($current_version && ($version eq $current_version) )
			{
				$$self{'errstr'} = "V $version found with dates $current_date and $date";

				if ($$self{'_verbose'})
				{
					$self -> log($$self{'errstr'});
				}
			}

			@comment         = ();
			$current_date    = $date;
			$current_version = $version;
		}
	}

	# Step 3: Wrap up the last version, if any.

	if ($current_version)
	{
		$release = {Version => $current_version, Date => $current_date, Comments => [@comment]};

		push @release, $release;
	}

	# Scan the releases looking for security advisories.

	my($security);

	for $release (0 .. $#release)
	{
		$security = 0;

		for $line (@{$release[$release]{'Comments'} })
		{
			if ($line =~ /Security/i)
			{
				$security = 1;

				last;
			}
		}

		if ($security)
		{
			$release[$release]{'Deploy.Action'} = 'Upgrade';
			$release[$release]{'Deploy.Reason'} = 'Security';
		}
	}

	# Sort by version number to put the latest version at the top of the file.

	my($section);

	for $release (reverse sort{$$a{'Version'} cmp $$b{'Version'} } @release)
	{
		$section = "V $$release{'Version'}";

		$$self{'config'} -> AddSection($section);
		$$self{'config'} -> newval($section, 'Date', $$release{'Date'});

		# Put these near the top of this release's notes.

		if ($$release{'Deploy.Action'})
		{
			$$self{'config'} -> newval($section, 'Deploy.Action', $$release{'Deploy.Action'});
			$$self{'config'} -> newval($section, 'Deploy.Reason', $$release{'Deploy.Reason'} || '');
		}

		$$self{'config'} -> newval($section, 'Comments', @{$$release{'Comments'} });
	}

} # End of convert_body.

# ------------------------------------------------

sub errstr
{
	my($self) = @_;

	return $$self{'errstr'};

} # End of errstr.

# ------------------------------------------------

sub get_latest_release
{
	my($self)    = @_;
	my(@release) = $$self{'config'} -> GroupMembers('V');

	my(@output);
	my($release);
	my($version);

	for $release (@release)
	{
		($version = $release) =~ s/^V //;

		push @output, version -> new($version);
	}

	@output = reverse sort{$a cmp $b} @output;

	my($result) = {};

	if ($#output >= 0)
	{
		my($section) = "V $output[0]";

		my($token);

		for $token ($$self{'config'} -> Parameters($section) )
		{
			$$result{$token} = $$self{'config'} -> val($section, $token);
		}
	}

	return $result;

} # End of get_latest_release.

# ------------------------------------------------

sub get_latest_version
{
	my($self)    = @_;
	my(@release) = $$self{'config'} -> GroupMembers('V');

	my(@output);
	my($release);
	my($version);

	for $release (@release)
	{
		($version = $release) =~ s/^V //;

		push @output, version -> new($version);
	}

	@output = reverse sort{$a cmp $b} @output;

	return $#output >= 0 ? $output[0] : '';

} # End of get_latest_version.

# ------------------------------------------------

sub log
{
	my($self, $message) = @_;

	print STDERR "$message\n";

} # End of log.

# ------------------------------------------------

sub new
{
	my($class, $arg) = @_;
	my($self)        = bless({}, $class);

	for my $attr_name ($self -> _standard_keys() )
	{
		my($arg_name) = $attr_name =~ /^_(.*)/;

		if (exists($$arg{$arg_name}) )
		{
			$$self{$attr_name} = $$arg{$arg_name};
		}
		else
		{
			$$self{$attr_name} = $self -> _default_for($attr_name);
		}
	}

	# The -webPage option automatically activates the -table option.

	if ($$self{'_webPage'})
	{
		$$self{'_table'} = 1;
	}

	$$self{'config'} = '';
	$$self{'errstr'} = '';

	return $self;

}	# End of new.

#  -----------------------------------------------

sub parse_datetime
{
	my($self, $candidate) = @_;
	my($date) = $self -> parse_datetime_1($candidate);

	if ($@ =~ /Could not parse date/)
	{
		$@    = '';
		$date = $self -> parse_datetime_2('%A%n%B%n%d%n%Y', $candidate);

		if ($date eq 'Could not parse date')
		{
			$candidate =~ s/(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s*//;
			$date      = $self -> parse_datetime_2('%B%n%d%n%Y', $candidate);
		}
	}

	return $@ || $date;

} # End of parse_datetime.

#  -----------------------------------------------

sub parse_datetime_1
{
	my($self, $candidate) = @_;

	my($date);

	require 'DateTime/Format/HTTP.pm';

	eval{$date = DateTime::Format::HTTP -> parse_datetime($candidate)};

	return $@ || $date;

} # End of parse_datetime_1.

#  -----------------------------------------------

sub parse_datetime_2
{
	my($self, $pattern, $candidate) = @_;
	$candidate =~ s/([0-9]+)(st|nd|rd|th)/$1/; # Zap st from 1st, etc.

	require 'DateTime/Format/Strptime.pm';

	my($parser) = DateTime::Format::Strptime -> new(pattern => $pattern);

	return $parser -> parse_datetime($candidate) || 'Could not parse date';

} # End of parse_datetime_2.

#  -----------------------------------------------

sub read
{
	my($self, $input_file_name) = @_;
	$input_file_name            ||= 'Changelog.ini';
	$$self{'config'}            = Config::IniFiles -> new(-file => $input_file_name);

	# Return object for method chaining.

	return $self -> validate($input_file_name);

} # End of read.

#  -----------------------------------------------

sub report
{
	my($self)        = @_;
	my($module_name) = $$self{'config'} -> val('Module', 'Name');
	my($width)       = 15;

	my(@output);

	push @output, ['Module', $module_name];
	push @output, ['-' x $width, '-' x $width];

	my($found)   = 0;
	my(@release) = $$self{'config'} -> GroupMembers('V');

	my($date, $deploy_action, $deploy_reason);
	my($release);
	my($version);

	for $release (@release)
	{
		($version = $release) =~ s/^V //;

		next if ($$self{'_release'} && ($version ne $$self{'_release'}) );

		$date          = $$self{'config'} -> val($release, 'Date');
		$deploy_action = $$self{'config'} -> val($release, 'Deploy.Action');
		$deploy_reason = $$self{'config'} -> val($release, 'Deploy.Reason');
		$found         = 1;

		push @output, ['Version', $version];
		push @output, ['Date', $date];

		if ($deploy_action)
		{
			push @output, ['Deploy.Action', $deploy_action];
			push @output, ['Deploy.Reason', $deploy_reason];
		}

		push @output, ['-' x $width, '-' x $width];
	}

	if (! $found)
	{
		push @output, ['Warning', "V $$self{'_release'} not found"];
	}

	if ($$self{'_table'})
	{
		$self -> report_as_html(@output);
	}
	else
	{
		# Report as text.

		for (@output)
		{
			printf "%-${width}s %s\n", $$_[0], $$_[1];
		}
	}

} # End of report.

#  -----------------------------------------------

sub report_as_html
{
	my($self, @output) = @_;

	if (! $$self{'_pathForHTML'})
	{
		my($my_home)           = File::HomeDir -> my_home() || '.';
		$$self{'_pathForHTML'} = "$my_home/httpd/prefork/htdocs/assets/templates/module/metadata/changes";
	}

	my($template) = HTML::Template -> new(path => $$self{'_pathForHTML'}, filename => 'ini.table.tmpl');
	@output       = map
	{
		{
			th => $Entitize{$$_[0]},
			td => $Entitize{$$_[1]},
			td_class => $$_[0] =~ /Deploy/ ? 'ini_deploy' : 'ini_td',
		}
	} @output;

	$template -> param(tr_loop => [@output]);

	my($content) = $template -> output();

	if ($$self{'_webPage'})
	{
		$template = HTML::Template -> new(path => $$self{'_pathForHTML'}, filename => 'ini.page.tmpl');

		$template -> param(content => $content);
		$template -> param(url_for_css => $$self{'_urlForCSS'});

		$content = $template -> output();
	}
	
	print $content;

} # End of report_as_html.

#  -----------------------------------------------

sub run
{
	my($self) = @_;

	# If converting, inFileName is the name of an old-style CHANGES file,
	# and outFileName is the name of a new-style Changelog.ini file.
	# If reporting on a specific release, inFileName is the name of
	# a new-style Changelog.ini file.

	if ($$self{'_convert'})
	{
		$self -> convert($$self{'_inFileName'});
	}
	else
	{
		$self -> read($$self{'_inFileName'});
		$self -> report();
	}

	# Return 0 for success in case someone wants to know.

	return 0;

} # End of run.

#  -----------------------------------------------

sub validate
{
	my($self, $input_file_name) = @_;

	# Validate existence of Module section.

	if (! $$self{'config'} -> SectionExists('Module') )
	{
		Carp::croak "Error: Section 'Module' is missing from $input_file_name";
	}

	# Validate existence of Name within Module section.

	my($module_name) = $$self{'config'} -> val('Module', 'Name');

	if (! defined $module_name)
	{
		Carp::croak "Error: Section 'Module' is missing a 'Name' token in $input_file_name";
	}

	# Validate existence of Releases.

	my(@release) = $$self{'config'} -> GroupMembers('V');

	if ($#release < 0)
	{
		Carp::croak "Error: No releases (sections like [V \$version]) found in $input_file_name";
	}

	my($parser) = DateTime::Format::W3CDTF -> new();

	my($candidate);
	my($date);
	my($release);
	my($version);

	for $release (@release)
	{
		($version = $release) =~ s/^V //;

		# Validate Date within each Release.

		$candidate = $$self{'config'} -> val($release, 'Date');
		eval{$date = $parser -> parse_datetime($candidate)};

		if ($@)
		{
			Carp::croak "Error: Date $candidate is not in W3CDTF format";
		}
	}

	if ($$self{'_verbose'})
	{
		$self -> log("Successful validation of file: $input_file_name");
	}

	# Return object for method chaining.

	return $self;

} # End of validate.

#  -----------------------------------------------

sub write
{
	my($self, $output_file_name) = @_;
	$output_file_name            ||= 'Changelog.ini';

	$$self{'config'} -> WriteConfig($output_file_name);

	if ($$self{'_verbose'})
	{
		$self -> log("Output file: $output_file_name");
	}

	# Return object for method chaining.

	return $self;

} # End of write.

#  -----------------------------------------------

1;

=head1 NAME

C<Module::Metadata::Changes> - Manage a module's machine-readable C<Changelog.ini> file

=head1 Synopsis

	shell>ini.report.pl -h
	shell>ini.report.pl -c
	shell>ini.report.pl -r 1.23
	shell>ini.report.pl -w > $HOME/httpd/prefork/htdocs/Changelog.html
	shell>perl -MModule::Metadata::Changes -e 'Module::Metadata::Changes->new()->convert()'
	shell>perl -MModule::Metadata::Changes -e 'print Module::Metadata::Changes->new()->read()->get_latest_version()'

This module ships with C<ini.report.pl> in the bin/ directory.

=head1 Description

C<Module::Metadata::Changes> is a pure Perl module.

It allows you to convert old-style C<CHANGES> files, and to read and write C<Changelog.ini> files.

=head1 Distributions

This module is available as a Unix-style distro (*.tgz).

See http://savage.net.au/Perl-modules.html for details.

See http://savage.net.au/Perl-modules/html/installing-a-module.html for
help on unpacking and installing.

=head1 Constructor and initialization

new(...) returns an object of type C<Module::Metadata::Changes>.

This is the class's contructor.

Usage: C<< Module::Metadata::Changes -> new() >>.

This method takes a hashref of options. There are no mandatory options.

Call C<new()> as C<< new({option_1 => value_1, option_2 => value_2, ...}) >>.

Available options:

=over 4

=item convert

This takes the value 0 or 1.

The default is 0.

If the value is 0, calling C<run()> calls C<read()> and C<report()>.

If the value is 1, calling C<run()> calls C<convert()>.

=item inFileName

The default is './CHANGES' when calling C<convert()>, and './Changelog.ini' when calling C<read()>.

=item outFileName

The default is './Changelog.ini'.

=item pathForHTML

This is path to the HTML::Template-style templates used by the 'table' and 'webPage' options.

The default is "$my_home/httpd/prefork/htdocs/assets/templates/module/metadata/changes",
where $my_home is what's returned by File::HomeDir -> my_home(). If this returns undef,
then $my_home is set to '.'.

=item release

The default is ''.

If this option has a non-empty value, the value is assumed to be a release/version number.

In that case, reports (text, HTML) are restricted to only the given version.

The default ('') means reports contain all versions.

'release' was chosen, rather than 'version', in order to avoid a clash with 'verbose',
since all options could then be abbreviated to 1 letter. Also, a lot of other software
uses -r to refer to release/version.

=item table

This takes the value 0 or 1.

The default is 0.

This option is only used when C<report()> is called.

If the value is 0, calling C<report()> outputs a text report.

If the value is 1, calling C<report()> outputs a HTML report.

By default, the HTML report will just be a HTML table.

However, if the 'webPage' option is 1, the HTML will be a complete web page.

=item urlForCSS

The default is '/assets/css/module/metadata/changes/ini.css'.

This is only used if the 'webPage' option is 1.

=item verbose

This takes the value 0 or 1.

The default is 0.

If the value is 1, C<convert()>, C<validate()> and C<write()> write progress reports to STDERR.

=item webPage

This takes the value 0 or 1.

The default is 0.

A value of 1 automatically sets 'table' to 1.

If the value is 0, the 'table' option outputs just a HTML table.

If the value is 1, the 'table' option outputs a complete web page.

=back

=head1 Method: convert([$input_file_name])

This method parses the given file, assuming it's format is the common-or-garden C<CHANGES> style.

The $input_file_name is optional. It defaults to 'CHANGES'.

C<convert()> calls C<write()>.

Return value: The object, for method chaining.

=head1 Method: convert_body(...)

Used by C<convert()>.

=head1 Method: errstr

Returns the last error message, or ''.

Currently, the only error message is when parsing an old-style C<CHANGES> file,
and a version number appears twice, with 2 different dates.

=head1 Method: get_latest_release()

Returns an hash ref of the latest release's data.

Returns {} if there is no such release.

The hash keys are (most of) the reserved tokens, as discussed below in the FAQ.

Some reserved tokens, such as EOT, make no sense as hash keys.

=head1 Method: get_latest_version()

Returns the version number of the latest version.

Returns '' if there is no such version.

=head1 Method: parse_datetime()

Used by C<convert()>.

=head1 Method: parse_datetime_1()

Used by C<convert()>.

=head1 Method: parse_datetime_2()

Used by C<convert()>.

=head1 Method: read([$input_file_name])

This method reads the given file, using C<Config::IniFiles>.

The $input_file_name is optional. It defaults to 'Changelog.ini'.

Return value: The object, for method chaining.

=head1 Method: report()

Displays various items for one or all releases.

If the 'release' option to C<new()> was not used, displays items for all releases.

If 'release' was used, restrict the report to just that release/version.

If either the 'table' or 'webPage' options to C<new()> were used, output HTML by calling C<report_as_html()>.

If these latter 2 options were not used, output text.

HTML is escaped using C<HTML::Entities::Interpolate>.

Output is to STDOUT.

=head1 Method: report_as_html()

Displays various items as HTML for one or all releases.

If the 'release' option to C<new()> was not used, displays items for all releases.

If 'release' was used, restrict the report to just that release/version.

Warning: This method must be called via the C<report()> method.

Output is to STDOUT.

=head1 Method: run()

Use the options passed to C<new()> to determine what to do.

Calling C<< new({convert => 1}) >> and then C<run()> will cause C<convert()> to be called.

If you don't set 'convert' to 1, C<run()> will call C<read()> and C<report()>.

Return value: 0.

=head1 Method: validate($file_name)

This method is used by C<read()> to validate the contents of the file read in.

C<validate()> does not read the file.

C<validate()> calls Carp::croak when a validation test fails.

Return value: The object, for method chaining.

=head1 Method: write([$output_file_name])

This method writes the data, using C<Config::IniFiles>, to the given file.

The $output_file_name is optional. It defaults to 'Changelog.ini'.

Return value: The object, for method chaining.

=head1 FAQ

=over 4

=item What is the format of C<Changelog.ini>?

Here is a sample:

	[Module]
	Name=CGI::Session
	Changelog.Creator=Module::Metadata::Changes V 1.00
	Changelog.Parser=Config::IniFiles V 2.39

	[V 4.30]
	Date=2008-04-25T00:00:00
	Comments= <<EOT
	* FIX: Patch POD for CGI::Session in various places, to emphasize even more that auto-flushing is
	unreliable, and that flush() should always be called explicitly before the program exits.
	The changes are a new section just after SYNOPSIS and DESCRIPTION, and the PODs for flush(),
	and delete(). See RT#17299 and RT#34668
	* NEW: Add t/new_with_undef.t and t/load_with_undef.t to explicitly demonstrate the effects of
	calling new() and load() with various types of undefined or fake parameters. See RT#34668
	EOT

	[V 4.10]
	Date=2006-03-28T00:00:00
	Deploy.Action=Upgrade
	Deploy.Reason=Security
	Comments= <<EOT
	* SECURITY: Hopefully this settles all of the problems with symlinks. Both the file
	and db_file drivers now use O_NOFOLLOW with open when the file should exist and
	O_EXCL|O_CREAT when creating the file. Tests added for symlinks. (Matt LeBlanc)
	* SECURITY: sqlite driver no longer attempts to use /tmp/sessions.sqlt when no
	Handle or DataSource is specified. This was a mistake from a security standpoint
	as anyone on the machine would then be able to create and therefore insert data
	into your sessions. (Matt LeBlanc)
	* NEW: name is now an instance method (RT#17979) (Matt LeBlanc)
	EOT

=item How do I display such a file?

See C<bin/ini.report.pl>. It outputs text or HTML.

=item What are the reserved tokens in this format?

I'm using tokens to refer to both things in [] such as Module, and things on the left hand side
of the = signs, such as Date.

And yes, these tokens are case-sensitive.

The tokens are listed here in alphabetical order.

=over 4

=item Comments

=item Changelog.Creator

This token may be missing on a file being read, but will always be added to a file being written.

=item Changelog.Parser

This token may be missing. It is documentation, so everyone knows which module can definitely
read this format. It too will always be added to a file being written.

=item Date

The datetime of the release, in W3CDTF format.

This is used as, say, Date=2008-04-25T00:00:00, in the [V 1.23] section of a C<Changelog.ini> file.

I know the embedded 'T' makes this format a bit harder to read, but the idea is that such files
will normally be processed by a program.

=item Deploy.Action

The module author's recommendation to the end user.

This enables the end user to quickly grep the C<Changelog.ini>, or the output of C<ini.report.pl>,
for things like security fixes and API changes.

Run 'bin/ini.report.pl -h' for help.

Suggestions:

	Deploy.Action=Upgrade
	Deploy.Reason=(Security|Major bug fix)

	Deploy.Action=Upgrade with caution
	Deploy.Reason=(Major|Minor) API change/Development version

Alternately, the classic syslog tokens could perhaps be used:

Debug/Info/Notice/Warning/Error/Critical/Alert/Emergency.

I think the values for these 2 tokens (Deploy.*) should be kept terse, and the Comments section used
for an expanded explanation, if necessary.

Omitting Deploy.Action simply means the module's author leaves it up to the end user to
read the comments and make up their own mind.

C<convert()> called directly, or via C<ini.report.pl -c> (i.e. old format to ini format converter),
inserts these 2 tokens if it sees the word /Security/i in the Comments. It's a crude but automatic warning
to end users. The HTML output options (C<-t> and C<-w>) use red text via CSS to highlight these 2 tokens.

Of course security is best handled by the module's author explicitly inserting a suitable note.

And, lastly, any such note is purely up to the author's judgement, which means differences in
opinion are inevitable.

=item Deploy.Reason

The module author's reason for their recommended action.

=item EOT

Config::IniFiles uses EOT to terminate multi-line comments.

If C<convert_body()> finds a line beginning with EOT, it jams a '-' in front of it.

=item Module

This is used as the name of a section. I.e. as [Module].

=item Name

The name of the module.

This is used as, say, Name=Module::Metadata::Changes, in the [Module] section of a C<Changelog.ini> file.

=item V

This is used as the name of a section, i.e. as in [V 1.23].

The V makes it easy for the validation code to ensure there is a least one release in the file.

C<Config::IniFiles> calls the V in [V 1.23] a Group Name.

=back

=item Why aren't there more reserved tokens?

Various reasons:

=over 4

=item Any one person, or any group, can standardize on their own tokens

Obviously, it would help if they advertised their choice, firstly so as to get as
many people as possible using the same tokens, and secondly to get agreement on the
interpretation of those choices.

Truely, there is no point in any particular token if it is not given a consistent meaning.

=item You can simply add your own to your C<Changelog.ini> file

They will then live on as part of the file.

=back

Special processing is normally only relevant when converting an old-style C<CHANGES> file
to a new-style C<Changelog.ini> file.

However, if you think the new tokens are important enough to be displayed as part of the text
and HTML format reports, let me know.

I have deliberately not included the Comments in reports since you can always just examine the
C<Changelog.ini> file itself for such items. But that too could be changed.

=item Are single-line comments acceptable?

Sure. Here's one:

	Comments=* INTERNAL: No Changes since 4.20_1. Declaring stable.

The '*' is not special, it's just part of the comment.

=item What's with the datetime format?

It's called W3CDTF format. See:

http://search.cpan.org/dist/DateTime-Format-W3CDTF/

See also ISO8601 format:

http://search.cpan.org/dist/DateTime-Format-ISO8601/

=item Why this file format?

Various reasons:

=over 4

=item [Module] allows for [Script], [Library], and so on.

=item *.ini files are easy for beginners to comprehend

=item Other formats were considered. I made a decision

There is no perfect format which will please everyone.

Various references, in no particular order:

http://use.perl.org/~miyagawa/journal/34850

http://use.perl.org/~hex/journal/34864

http://redhanded.hobix.com/inspect/yamlIsJson.html

http://use.perl.org/article.pl?sid=07/09/06/0324215

http://use.perl.org/comments.pl?sid=36862&cid=57590

http://use.perl.org/~RGiersig/journal/34370/

=item The module C<Config::IniFiles> already existed, for reading and writing this format

Specifically, C<Config::IniFiles> allows for here documents, which I use to hold the comments
authors produce for most of their releases.

=back

=item What's the difference between release and version?

I'm using release to refer not just to the version number, but also to all the notes
relating to that version.

And by notes I mean everything in one section under the name [V $version].

=item Will you switch to YAML or XML format?

YAML? No, never. It is targetted at other situations, and while it can be used for simple
applications like this, it can't be hand-written I<by beginners>.

And it's unreasonable to force people to write a simple program to write a simple YAML file.

XML? Nope. It's great is I<some> situations, but too visually dense and slow to write for this one.

=item What about adding Changed Requirements to the file?

No. That info will be in the changed C<Build.PL> or C<Makefile.PL> files.

It's a pointless burden to make the module's author I<also> add that to C<Changelog.ini>.

=item Who said you had the power to decide on this format?

No-one. But I do have the time and the inclination to maintain C<Module::Metadata::Changes>
indefinitely.

Also, I had a pressing need for a better way to manage metadata pertaining my own modules,
for use in my database of modules.

One of the reports I produce from this database is visible here:

http://savage.net.au/Perl-modules.html

Ideally, there will come a time when all of a person's modules, if not the whole of CPAN,
will have C<Changelog.ini> files, so producing such a report will be easy, and hence will be
that much more likely to happen.

=item Why not use, say, C<Config::Tiny> to process C<Changelog.ini> files?

Because C<Config::Tiny> contains this line, 's/\s\;\s.+$//g;', so it will mangle
text containing English semi-colons.

Also, authors add comments per release, and most C<Config::*> modules only handle lines
of the type X=Y.

=item How are the old C<CHANGES> files parsed?

The first line is scanned looking for /X::Y/ or /X\.$/. And yes, it fails for modules
which identify themselves like Fuse-PDF not at the end of the line.

Then lines looking something like /$a_version_number ... $a_datetime/ are searched for.
This is deemed to be the start of information pertaining to a specific release.

Everything up to the next release, or EOF, is deemed to belong to the release just
identified.

This means a line containing a version number without a date is not recognized as a new release,
so that that line and the following comments are added to the 'current' release's info.

For an example of this, process the C<Changes> file from CGI::Session (t/Changes), and scan the
output for '[4.00_01]', which you'll see contains stuff for V 3.12, 3.8 and 3.x.

See above, under the list of reserved tokens, for how security advisories are inserted in the output
stream.

Remember, as stated above, C<convert()> calls C<write()>.

=item Is this conversion process perfect?

Well, no, actually, but it'll be as good as I can make it.

For example, version numbers like '3.x' are turned into '3.'.

You'll simply have to scrutinize (which means 'read I<carefully>') the output of this conversion process.

If a C<CHANGES> file is not handled by the current version, log a bug report on Request Tracker:
http://rt.cpan.org/Public/

=item How are datetimes in old-style files parsed?

Firstly try C<DateTime::Format::HTTP>, and if that fails, try these steps:

=over 4

=item Strip 'st' from 1st, 'nd' from 2nd, etc

=item Try C<DateTime::Format::Strptime>

=item If that fails, strip Monday, etc, and retry C<DateTime::Format::Strptime>

I noticed some dates were invalid because the day of the week did not match
the day of the month. So, I arbitrarily chop the day of the week, and retry.

=back

=item Why did you choose these 2 modules?

I had a look at a few C<CHANGES> files, and these made sense.

If appropriate, other modules can be added to the algorithm.

See the discussion on this page (search for 'parse multiple formats'):

http://datetime.perl.org/index.cgi?FAQBasicUsage

If things get more complicated, I'll reconsider using C<DateTime::Format::Builder>.

=item What happens for 2 releases on the same day?

It depends whether or not the version numbers are different.

C<CGI::Session's> C<Changes> file contains 2 references to version 4.06 :-(.

As long as the version numbers are different, the date doesn't actually matter.

=item Won't a new file format mean more work for those who maintain CPAN?

Yes, I'm afraid so, unless they completely ignore me!

But I'm hopeful this will lead to less work overall.

=item Why didn't you use the C<Template Toolkit> for the HTML?

It's too complex for this tiny project.

=item Where do I go for support?

Log a bug report on Request Tracker: http://rt.cpan.org/Public/

If it concerns failure to convert a specific C<CHANGES> file, just provide the name of
the module and the version number.

It would help - if the problem is failure to parse a specific datetime format - if you could
advise me on a suitable C<DateTime::Format::*> module to use.

=back

=head1 Required Modules

=over 4

=item use Carp

=item DateTime::Format::HTTP

=item DateTime::Format::Strptime

=item DateTime::Format::W3CDTF

=item HTML::Entities::Interpolate

=item HTML::Template

=item version

=back

=head1 See also

C<Module::Changes>: http://search.cpan.org/dist/Module-Changes-0.05/

=head1 Author

C<Module::Metadata::Changes> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2008.

Home page: http://savage.net.au/index.html

=head1 Copyright

Australian copyright (c) 2008, Ron Savage. All rights reserved.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
