package Module::Metadata::Changes;

use strict;
use warnings;

use Config::IniFiles;

use DateTime::Format::W3CDTF;

use Hash::FieldHash ':all';

use HTML::Entities::Interpolate;
use HTML::Template;

use Perl6::Slurp; # For slurp.

use version;

fieldhash my %config      => 'config';
fieldhash my %convert     => 'convert';
fieldhash my %errstr      => 'errstr';
fieldhash my %inFileName  => 'inFileName';
fieldhash my %module_name => 'module_name';
fieldhash my %outFileName => 'outFileName';
fieldhash my %pathForHTML => 'pathForHTML';
fieldhash my %release     => 'release';
fieldhash my %table       => 'table';
fieldhash my %urlForCSS   => 'urlForCSS';
fieldhash my %verbose     => 'verbose';
fieldhash my %webpage     => 'webPage';

our $VERSION = '1.09';

# ------------------------------------------------

sub get_latest_release
{
	my($self)    = @_;
	my(@release) = $self -> config -> GroupMembers('V');

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

		for $token ($self -> config -> Parameters($section) )
		{
			$$result{$token} = $self -> config -> val($section, $token);
		}
	}

	return $result;

} # End of get_latest_release.

# ------------------------------------------------

sub get_latest_version
{
	my($self)    = @_;
	my(@release) = $self -> config -> GroupMembers('V');

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

# -----------------------------------------------

sub init
{
	my($self, $arg)    = @_;
	$$arg{convert}     ||= 0;
	$$arg{errstr}      = '';
	$$arg{inFileName}  ||= '';
	$$arg{outFileName} ||= 'Changelog.ini';
	$$arg{pathForHTML} ||= '/var/www/assets/templates/module/metadata/changes';
	$$arg{release}     ||= '';
	$$arg{table}       ||= 0;
	$$arg{urlForCSS}   ||= '/assets/css/module/metadata/changes/ini.css';
	$$arg{verbose}     ||= 0;
	$$arg{webPage}     ||= 0;

} # End of init.

# -----------------------------------------------

sub log
{
	my($self, $s) = @_;
	$s ||= '';

	if ($self -> verbose)
	{
		print STDERR "$s\n";
	}

} # End of log.

# -----------------------------------------------

sub new
{
	my($class, %arg) = @_;

	$class -> init(\%arg);

	my($self) = from_hash(bless({}, $class), \%arg);

	if ($self -> webPage)
	{
		$self -> table(1);
	}

	return $self;

} # End of new.

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
	my($self, $in_file_name) = @_;
	$in_file_name            ||= 'Changelog.ini';

	$self -> config(Config::IniFiles -> new(-file => $in_file_name) );

	# Return object for method chaining.

	return $self -> validate($in_file_name);

} # End of read.

#  -----------------------------------------------

sub reader
{
	my($self, $in_file_name) = @_;
	$in_file_name            ||= 'CHANGES';
	my(@line)                = slurp $in_file_name, {chomp => 1};

	$self -> log("Input file: $in_file_name");

	# Get module name from the first line.
	# 1st guess at format: /Revision history for Perl extension Local::Wine./

	my($line)        = shift @line;
	$line            =~ s/\s+$//;
	$line            =~ s/\s*\.\s*$//;
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

	$self -> module_name($module_name);
	$self -> log("Module: $module_name (from 1st line of $in_file_name)");

	return $self -> transform(@line);

} # End of reader.

#  -----------------------------------------------

sub report
{
	my($self)        = @_;
	my($module_name) = $self -> config -> val('Module', 'Name');
	my($width)       = 15;

	my(@output);

	push @output, ['Module', $module_name];
	push @output, ['-' x $width, '-' x $width];

	my($found)   = 0;
	my(@release) = $self -> config -> GroupMembers('V');

	my($date, $deploy_action, $deploy_reason);
	my($release);
	my($version);

	for $release (@release)
	{
		($version = $release) =~ s/^V //;

		$self -> log("Checking " . $self -> release . ' and ' . $version);

		next if ($self -> release && ($version ne $self -> release) );

		$date          = $self -> config -> val($release, 'Date');
		$deploy_action = $self -> config -> val($release, 'Deploy.Action');
		$deploy_reason = $self -> config -> val($release, 'Deploy.Reason');
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
		push @output, ['Warning', "V @{[$self -> release]} not found"];
	}

	if ($self -> table)
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
	my($template) = HTML::Template -> new(path => $self -> pathForHTML, filename => 'ini.table.tmpl');
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

	if ($self -> webPage)
	{
		$template = HTML::Template -> new(path => $self -> pathForHTML, filename => 'ini.page.tmpl');

		$template -> param(content => $content);
		$template -> param(url_for_css => $self -> urlForCSS);

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

	if ($self -> convert)
	{
		$self -> writer($self -> reader($self -> inFileName) );
	}
	else
	{
		$self -> read($self -> inFileName);
		$self -> report;
	}

	# Return 0 for success in case someone wants to know.

	return 0;

} # End of run.

#  -----------------------------------------------

sub transform
{
	my($self, @line) = @_;

	my($current_version, $current_date, @comment);	my($date);
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
		# Each release is expected to start with one of:
		# o 1.05  Fri Jan 25 10:08:00 2008
		# o 4.30 - Friday, April 25, 2008
		# o 4.08 - Thursday, March 15th, 2006

		$line  =~ tr/ / /s;
		$line  =~ s/,//g;
		@field = split(/\s(?:-\s)?/, $line, 2);

		# The "" keeps version happy.

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

			if ($version && $date)
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
				$self -> errstr("V $version found with dates $current_date and $date");

				$self -> log($self -> errstr);
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

	return [@release];

} # End of transform.

#  -----------------------------------------------

sub validate
{
	my($self, $in_file_name) = @_;

	# Validate existence of Module section.

	if (! $self -> config -> SectionExists('Module') )
	{
		die "Error: Section 'Module' is missing from $in_file_name";
	}

	# Validate existence of Name within Module section.

	my($module_name) = $self -> config -> val('Module', 'Name');

	if (! defined $module_name)
	{
		die "Error: Section 'Module' is missing a 'Name' token in $in_file_name";
	}

	# Validate existence of Releases.

	my(@release) = $self -> config -> GroupMembers('V');

	if ($#release < 0)
	{
		die "Error: No releases (sections like [V \$version]) found in $in_file_name";
	}

	my($parser) = DateTime::Format::W3CDTF -> new;

	my($candidate);
	my($date);
	my($release);
	my($version);

	for $release (@release)
	{
		($version = $release) =~ s/^V //;

		# Validate Date within each Release.

		$candidate = $self -> config -> val($release, 'Date');
		eval{$date = $parser -> parse_datetime($candidate)};

		if ($@)
		{
			die "Error: Date $candidate is not in W3CDTF format";
		}
	}

	$self -> log("Successful validation of file: $in_file_name");

	# Return object for method chaining.

	return $self;

} # End of validate.

#  -----------------------------------------------

sub write
{
	my($self, $output_file_name) = @_;
	$output_file_name            ||= 'Changelog.ini';

	$self -> config -> WriteConfig($output_file_name);

	$self -> log("Output file: $output_file_name");

	# Return object for method chaining.

	return $self;

} # End of write.

#  -----------------------------------------------

sub writer
{
	my($self, $release) = @_;

	$self -> config(Config::IniFiles -> new);
	$self -> config -> AddSection('Module');
	$self -> config -> newval('Module', 'Name', $self -> module_name);
	$self -> config -> newval('Module', 'Changelog.Creator', __PACKAGE__ . " V $VERSION");
	$self -> config -> newval('Module', 'Changelog.Parser', "Config::IniFiles V $Config::IniFiles::VERSION");

	# Sort by version number to put the latest version at the top of the file.

	my($section);

	for my $r (reverse sort{$$a{'Version'} cmp $$b{'Version'} } @$release)
	{
		$section = "V $$r{'Version'}";

		$self -> config -> AddSection($section);
		$self -> config -> newval($section, 'Date', $$r{'Date'});

		# Put these near the top of this release's notes.

		if ($$r{'Deploy.Action'})
		{
			$self -> config -> newval($section, 'Deploy.Action', $$r{'Deploy.Action'});
			$self -> config -> newval($section, 'Deploy.Reason', $$r{'Deploy.Reason'} || '');
		}

		$self -> config -> newval($section, 'Comments', @{$$r{'Comments'} });
	}

	# Return object for method chaining.

	return $self -> write($self -> outFileName);

} # End of writer.

# -----------------------------------------------

1;

