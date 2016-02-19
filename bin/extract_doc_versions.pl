#!/usr/bin/perl
###############################################################################
# 
# Purpose: Provide translation status of OSGeoLive docs, extracted from git
# Author:  Cameron Shorter
# Usage: extract_doc_versions -o outputfile.html
#
###############################################################################
# Copyright (c) 2012 Open Source Geospatial Foundation (OSGeo)
# Copyright (c) 2012 LISAsoft
# Copyright (c) 2012 Cameron Shorter
#
# Licensed under the GNU LGPL.
# 
# This library is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 2.1 of the License,
# or any later version.  This library is distributed in the hope that
# it will be useful, but WITHOUT ANY WARRANTY, without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details, either
# in the "LICENSE.LGPL.txt" file distributed with this software or at
# web page "http://www.fsf.org/licenses/lgpl.html".
###############################################################################

use strict;
use warnings;
use File::Basename;
use Getopt::Std;

# initialise variables
my $osgeolive_docs_url="http://adhoc.osgeo.osuosl.org/livedvd/docs/";
my %gitinfo;
my $line;

# Get output file from the -o option, otherwise print to stdout
my %options=();
getopts("o:", \%options);
my $outfile = *STDOUT;
if ($options{o}) {
  open $outfile, ">", $options{o} || die "can't open output file $options{o}: $!\n";
}

&extract_git_info;

#&extract_review_status;
&print_header;
&print_summary;
&print_lang_versions;
&print_footer;

###############################################################################
# Print Header html
###############################################################################
sub print_header() {
  print $outfile "<html>\n";
  print $outfile "  <head>\n";
  print $outfile "    <title>OSGeo-Live Documentation translation status</title>\n";
  print $outfile "  </head>\n";
  print $outfile "  <body>\n";
  print $outfile "    <h1>OSGeo-Live Documentation translation status</h1>\n";
  print $outfile "    <p>Help translate - <a href='http://wiki.osgeo.org/wiki/Live_GIS_Translate'>click here!</a></p>\n";
  print $outfile "    <p><b>Last Updated:</b> ", `date`;
  print $outfile ". This page is calculated from document version numbers in git.</p>\n";
}

###############################################################################
# Print Footer html
###############################################################################
sub print_footer() {
  print $outfile "  </body>";
  print $outfile "</html>";
}

###############################################################################
# Extract information for osgeo-live document files and store in
# a hash array @gitlist
###############################################################################
sub extract_git_info() {
  # Store the script root directory for later
  my $scriptDir = dirname($0);

  my @files = split(/\n/, `git ls-tree -r --name-only HEAD`);

  # cd to the git document directory
  chdir("$scriptDir/..");

  foreach (@files) {
    if (
      m#^[a-z][a-z]/# # Match directories starting with 2 letter country code
      #&& m#.rst## # Only look at rst source docs
    ) {
      my $dir_file = $_;

      # extract $lang/$dir/$file
      my @file_bits = split /\//, $dir_file;
      my $lang=$file_bits[0];
      my $file=$file_bits[$#file_bits];
      my $dir;
      if ($#file_bits==2) {
        $dir=$file_bits[1];
      } else {
        $dir=".";
      }
      
      # Extract $commit_id,$author, $date, $version
      my @atribs= split (/,/, `git log -1 --format="%h,%an,%ai,%at" -- filename $dir_file`);

      # Extract info into a hash array
      $gitinfo{$lang}{"$dir/$file"}{"dir"}=$dir;
      $gitinfo{$lang}{"$dir/$file"}{"file"}=$file;
      $gitinfo{$lang}{"$dir/$file"}{"commit_id"}=$atribs[0];
      $gitinfo{$lang}{"$dir/$file"}{"author"}=$atribs[1];
      $gitinfo{$lang}{"$dir/$file"}{"date"}=$atribs[2];
      $gitinfo{$lang}{"$dir/$file"}{"version"}=$atribs[3];

      #print $outfile "lang=$lang,dir=$dir,file=$file,version=$atribs[0],author=$atribs[1],date=$atribs[2],version=$atribs[3]\n";
    }
  }
}

###############################################################################
# Extract Overview and Quickstart written and review status from Google
# Spreadsheet
###############################################################################
#sub extract_review_status() {
#  my $csv = Text::CSV->new();
#  my $google_doc_status_csv="https://docs.google.com/feeds/download/spreadsheets/Export?exportFormat=tsv&key=0Al9zh8DjmU_RdGIzd0VLLTBpQVJuNVlHMlBWSDhKLXc#gid=13"
#
#  open (my $file, "<", $google_doc_status_csv) or die $!;
#
#  while (my $line = <$file>) {
#    my @columns = split(/\t/, $line);
#    print "@columns\n";
#  }
#  close $file;
#}

###############################################################################
# Summarise tranlation status
###############################################################################
sub print_summary() {

  print $outfile "<a name='summary'/><h2>Summary</h2>\n";
  print $outfile "<table border='1'>\n";
  print $outfile "<tr><th>language</th><th>Sum up to date</th><th>Sum translated</th></tr>\n";

  # number of english files to translate
  my $sum_files=scalar keys %{$gitinfo{"en"}};

  # loop through languages
  foreach my $lang (sort keys %gitinfo) {
    # loop through filenames
    my $up_to_date=0;
    foreach my $dir_file (keys %{$gitinfo{"en"}}) {
      if (exists $gitinfo{$lang}{$dir_file}) {
        if ($gitinfo{$lang}{$dir_file}{'version'} >= $gitinfo{"en"}{$dir_file}{'version'}) {
          $up_to_date++;
        }
      }
    }
    my $translations=scalar keys %{$gitinfo{$lang}};
    my $translations_percent=int($translations*100/$sum_files);
    my $up_to_date_percent=int($up_to_date*100/$sum_files);
    print $outfile "<tr><td>$lang</td><td>$up_to_date ($up_to_date_percent%)</td>";
    print $outfile "<td>$translations ($translations_percent%)</td></tr>\n";
  }
  print $outfile "</table>\n";
}

###############################################################################
# print table showing file versions for each language
###############################################################################
sub print_lang_versions() {

  print $outfile "<a name='lang_versions'/><h2>Per file translation status</h2>\n";
  print $outfile "<p>Hyperlinks point to the difference in the English document since last translated.</p>\n";
  print $outfile "<table border='1'>\n";
  print $outfile "<tr><th>dir/file</th><th>date</th><th>en</th>\n";
  foreach my $lang (sort keys %gitinfo) {
    $lang =~ /en/ && next;
    print $outfile "<th>$lang</th>";
  }
  print $outfile "</tr>\n";

  # loop through filenames
  foreach my $dir_file (sort keys %{$gitinfo{"en"}}) {

    # print file/dir and url
    my $html_file=$gitinfo{'en'}{$dir_file}{'file'};
    $html_file=~s#.rst$#.html#;
    print $outfile "<tr><td>";
    print $outfile "<a href='$osgeolive_docs_url/en/";
    print $outfile "$gitinfo{'en'}{$dir_file}{'dir'}/$html_file'>";
    print $outfile "$dir_file</a></td>";

    # print date
    print $outfile "<td>$gitinfo{'en'}{$dir_file}{'date'}</td>";

    # print english version
    print $outfile "<td>$gitinfo{'en'}{$dir_file}{'version'}</td>";

    # loop through languages
    foreach my $lang (sort keys %gitinfo) {
      $lang =~ /en/ && next;

      # print language's version
      print $outfile "<td>";
      if (exists $gitinfo{$lang}{$dir_file} ) {
        if ($gitinfo{$lang}{$dir_file}{'version'} >= $gitinfo{"en"}{$dir_file}{'version'}) {
          print $outfile '<font color="green">';
          print $outfile "$gitinfo{$lang}{$dir_file}{'date'}";
          print $outfile "</font>";
        }else{

          # create a URL for the diff in en doc since last translated
          # Eg: http://trac.osgeo.org/osgeo/changeset?new=9055%40livedvd%2Fgisvm%2Ftrunk%2Fdoc%2Fde%2Foverview%2F52nSOS_overview.rst&old=9054%40livedvd%2Fgisvm%2Ftrunk%2Fdoc%2Fde%2Foverview%2F52nSOS_overview.rst
          my $url="http://trac.osgeo.org/osgeo/changeset?new=";
          $url .= $gitinfo{'en'}{$dir_file}{'version'};
          $url .= "%40livedvd%2Fgisvm%2Ftrunk%2Fdoc%2Fen%2F";
          if (!($gitinfo{'en'}{$dir_file}{'dir'} eq ".")) {
            $url .= $gitinfo{'en'}{$dir_file}{'dir'};
            $url .= "%2F";
          }
          $url .= $gitinfo{'en'}{$dir_file}{'file'};
          $url .= "&old=";
          $url .= $gitinfo{$lang}{$dir_file}{'version'};
          $url .= "%40livedvd%2Fgisvm%2Ftrunk%2Fdoc%2Fen%2F";
          if (!($gitinfo{'en'}{$dir_file}{'dir'} eq ".")) {
            $url .= $gitinfo{'en'}{$dir_file}{'dir'};
            $url .= "%2F";
          }
          $url .= $gitinfo{'en'}{$dir_file}{'file'};

          print $outfile "<a href='$url'>";
          print $outfile "$gitinfo{$lang}{$dir_file}{'date'}";
          print $outfile "</a>";
        }
      }
      print $outfile "</td>";
    }
    print $outfile "</tr>\n";
  }
  print $outfile "</table>\n";
}

