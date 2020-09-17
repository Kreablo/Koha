#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Data::Dumper;

BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use Koha::Script -cron;
use Getopt::Long;
use Koha::Patrons;
use Koha::Completion::AddressServiceBorrowerCompletion;
use Koha::Logger;
use C4::Context;
use Time::HiRes qw( usleep );

=head1 NAME

adresservice-update-borrowers.pl - Fetch adress information about borrowers from Adresservice and update accounts.

=head1 SYNOPSIS

adresservice-update-borrowers.pl [--verbose] [--confirm] [--category=<borrower category (multiple options)>]
                                 [--attribute-code=<code>]

update_patrons_category.pl --help

Options:
   --help                   brief help message
   -v -verbose              verbose mode
   -c --confirm             commit changes to db, no action will be taken unless this switch is included
   --category=<categorycode>limit updates to this borrower category (repeat for multiple categories)
   --attribute-code=<code>  The patron attribute code containing the personal number (default pnr).
   --usleep=<microseconds>  Time to sleep between API-calls.  Default: 100 microsecons.                 
=cut

my $help    = 0;
my $verbose = 0;
my $doit    = 0;
my $categories = undef;
my $code = 'pnr';
my $usleep = 100;

GetOptions(
    'help|?'          => \$help,
    'v|verbose'       => \$verbose,
    'c|confirm'       => \$doit,
    'category:s@'     => \$categories,
    'attribute-code:s'=> \$code,
    'usleep:i'        => \$usleep
);


if ($help) {
    pod2usage(1);
    exit;
}

( $verbose && !$doit ) and print "No actions will be taken (test mode)\n";

$verbose and print "Will update borrowers from " . (defined $categories ? "the categories " . join ", ", @$categories : "all categories") . "\n";

my %params = ();

$params{categorycode} = $categories if defined $categories;

my $target_patrons = Koha::Patrons->search(
    \%params
);

$verbose and print(($doit ? "Updating " : "Would update " . $target_patrons->count) . " borrowers\n");

C4::Context->interface('cron');
my $logger = Koha::Logger->get({ category => 'intranet.adresservice-update-borrowers.pl'});

BORROWERS: while ( my $target_patron = $target_patrons->next() ) {
     usleep($usleep);
    my $attrs = Koha::Patron::Attributes->search({
        borrowernumber => $target_patron->borrowernumber,
	code => $code
    });

    if ($verbose && $attrs->count == 0) {
	print "No personal number for " . $target_patron->borrowernumber . "\n";
    } else {
	my $pnrattr = $attrs->next;
	if ($attrs->count > 1) {
 	    $logger->warn("Multiple personal numbers for " . $target_patron->borrowernumber);
	    while (my $pnr0 = $attrs->next) {
		$logger->debug("Deleting extra personal number.");
		$pnr0->delete if $doit;
	    }
	}

	my $pnr = $pnrattr->attribute;

	print $pnr . "\n" if $verbose;

	my $dat = fetch_completions( $pnr );

	print Dumper($dat);

	if ($dat->{error}) {
	    $logger->error($dat->{error});
	    next;
	}

	my $dirty = 0;
	for my $p (@{$dat->{form_fields}}) {
	    my $n = $p->{name};
	    my $v = $p->{value};
	    my $t = $target_patron;
	    if ($n eq 'patron_attr_' && $p->{attrname} eq $code) {
		if ($v ne $pnrattr->attribute) {
		    $logger->debug($n  . ' update: "' . $v . '" ne "' . $pnrattr->attribute . '"');
		    $pnrattr->attribute($v);
		    $dirty = 1;
		}
	    } elsif ($n eq 'dateofbirth') {
		if ($t->dateofbirth ne $v) {
		    $logger->debug($n  . ' update: "' . $v . '" ne "' . $t->dateofbirth . '"');
		    $t->dateofbirth($v);
		    $dirty = 1;
		}
	    } elsif ($n eq 'address') {
		if ($t->address ne $v) {
		    $logger->debug($n  . ' update: "' . $v . '" ne "' . $t->address . '"');
		    $t->address($v);
		    $dirty = 1;
		}
	    } elsif ($n eq 'surname') {
		if ($t->surname ne $v) {
		    $logger->debug($n  . ' update: "' . $v . '" ne "' . $t->surname . '"');
		    $t->surname($v);
		    $dirty = 1;
		}
	    } elsif ($n eq 'city') {
		if ($t->city ne $v) {
		    $logger->debug($n  . ' update: "' . $v . '" ne "' . $t->city . '"');
		    $t->city($v);
		    $dirty = 1;
		}
	    } elsif ($n eq 'firstname') {
		if ($t->firstname ne $v) {
		    $logger->debug($n  . ' update: "' . $v . '" ne "' . $t->firstname . '"');
		    $t->firstname($v);
		    $dirty = 1;
		}
	    } elsif ($n eq 'zipcode') {
		if ($t->zipcode ne $v) {
		    $logger->debug($n  . ' update: "' . $v . '" ne "' . $t->zipcode . '"');
		    $t->zipcode($v);
		    $dirty = 1;
		}
	    } else {
		$logger->debug("Unexpected field in form fields: '" . $n . "'");
	    }
	}

	if ($dirty) {
	    $logger->info("Updating borrower " . $target_patron->borrowernumber);
	    $target_patron->store if $doit;
	}
    }	
}
