#!/usr/bin/perl
#
# Name:
#	ini.report.pl.
#
# Description:
#	Process old-style and new-style Changelog.ini files.

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Module::Metadata::Changes;

# --------------------

my($option_parser) = Getopt::Long::Parser -> new();

my(%option);

if ($option_parser -> getoptions
(
 \%option,
 'convert',
 'help',
 'inFileName=s',
 'outFileName=s',
 'pathForHTML=s',
 'release=s',
 'table',
 'urlForCSS=s',
 'verbose',
 'webPage',
) )
{
	pod2usage(1) if ($option{'help'});

	exit Module::Metadata::Changes -> new(\%option) -> run();
}
else
{
	pod2usage(2);
}

__END__

=pod

=head1 NAME

ini.report.pl - Process old-style and new-style Changelog.ini files

=head1 SYNOPSIS

ini.report.pl [options]

	Options:
	-convert
	-help
	-inFileName anInputFileName
	-outFileName anOutputFileName
	-pathForHTML aPathForHTML
	-release aVersionNumber
	-table
	-urlForCSS aURLForCSS
	-version
	-webPage

All switches can be reduced to a single letter.

Exit value: 0.

Typical switch combinations:

=over 4

=item No switches

Produce a text report on all versions.

=item -c

Convert CHANGES to Changelog.ini.

=item -r 1.23

Produce a text report on a specific version.

Since -c is not used, -i defaults to Changelog.ini.

=item -t

Produce a HTML report on all versions.

The report will just be a HTML C<table>, with CSS for Deploy.Action and Deploy.Reason.

The table can be embedded in your own web page.

=item -r 1.23 -t

Produce a HTML report on a specific version.

The report will just be a HTML C<table>, with CSS for Deploy.Action and Deploy.Reason.

The table can be embedded in your own web page.

=item -w

Produce a HTML report on all versions.

The report will be a HTML C<page>, with CSS for Deploy.Action and Deploy.Reason.

=item -r 1.23 -w

Produce a HTML report on a specific version.

The report will be a HTML C<page>, with CSS for Deploy.Action and Deploy.Reason.

=back

=head1 OPTIONS

=over 4

=item -convert

This specifies that the program is to read an old-style CHANGES file, and is to write a new-style
Changelog.ini file.

When -convert is used, the default -inFileName is CHANGES, and the default -outFileName is Changelog.ini.

=item -help

Print help and exit.

=item -inFileName anInputFileName

The name of a file to be read.

When the -convert switch is used, -inFileName defaults to CHANGES, and -outFileName
defaults to Changelog.ini.

In the absence of -convert, -inFileName defaults to Changelog.ini, and -outFileName
is not used.

=item -outFileName anOutputFileName

The name of a file to be written.

=item -pathForHTML aPathForHTML

The path to the HTML::Template-style templates used by the -table and -webPage switches.

Defaults to /var/www/assets/templates/module/metadata/changes.

=item -release aVersionNumber

Report on a specific release/version.

If this switch is not used, all versions are reported on.

=item -table

Output the report as a HTML table.

HTML is escaped using C<HTML::Entities::Interpolate>.

The table template is called ini.table.tmpl.

=item -urlForCSS aURLForCSS

The URL to insert into the web page, if using the -webPage switch,
which points to the CSS for the page.

Defaults to /assets/css/module/metadata/changes/ini.css.

=item -verbose

Print verbose messages.

=item -webPage

Output the report as a HTML page.

The page template is called ini.page.tmpl.

This switch automatically activates the -table switch.

=back

=head1 DESCRIPTION

ini.report.pl processes old-style and new-style Changelog.ini files.

=cut
