#!/usr/bin/perl -w

# LIBRIS Fjärrlån - Status på beställningar
# av Johan Sahlberg (johan.sahlberg@tidaholm.se), 2021

# Search string example:
# ./flstatus.pl branch=TIDA lfnumber=Tida-210416-0001

# Updated with authorization 2021-06-08

use Modern::Perl;
use CGI qw ( -utf8 );

use C4::Auth;

use HTML::Entities;
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;

my $query = CGI->new();

my ($template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
  {
	template_name => "intranet-main.tt",
	query	      => $query,
	type          => "intranet",
	flagsrequired => { catalogue => 1, }
  }
); 

# Search query
my $branch = $query->param('branch');
my $lfnumber = $query->param('lfnumber');

my $ua = new LWP::UserAgent;
$ua->agent("Perl API Client/1.0");

# Setup variables
my $string="librisfjarrlan/api/illrequests";
my $host="iller.libris.kb.se";
my $protocol="http";

# Build the url
my $url = "$protocol://$host/$string/$branch/$lfnumber";

# Fetch the actual data from the query
my $request = HTTP::Request->new("GET" => $url);
$request->content_type('application/json');

my $response = $ua->request($request);

my $cgi = CGI->new;
print $cgi->header(-type => "application/json", -charset => "utf-8");

my $jsonString = $response->content;

# Finally print JSON
print $jsonString;
