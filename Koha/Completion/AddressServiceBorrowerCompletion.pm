package Koha::Completion::AddressServiceBorrowerCompletion;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use strict;
use IO::Socket::SSL;
use SOAP::Lite;
use DateTime;
use Koha::Logger;

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw(fetch_completions);
our @EXPORT_OK = qw(normalize_pnr);


sub normalize_pnr {
    my $pnr = shift;

    if ($pnr =~ /^(\d{2}|\d{4})(\d{2})(\d{2})(?:[-+]?)(\d{4})$/) {
	my $y = int($1);
	my $m = int($2);
	my $d = int($3);
	my $n = int($4);

	if ($y < 100) {
	    my $cy = DateTime->now->year % 100;
	    if ($y < $cy) {
		$y += 2000;
	    } else {
		$y += 1900;
	    }
	}

	return (sprintf('%04d%02d%02d-%04d', $y, $m, $d, $n), sprintf('%04d%02d%02d%04d', $y, $m, $d, $n), sprintf('%04d-%02d-%02d', $y, $m, $d));
    }
    return undef;
}

sub name_capitalization {
    my $name = shift;

    my $s = '';
    my $first = 1;

    while (length($name) > 0) {
	my $c = substr($name, 0, 1);
	$name = substr($name, 1);
	if (!($c =~ /^\p{XPosixAlpha}+$/)) {
	    $first = 1;
	    $s .= $c;
	} elsif ($first) {
	    $first = 0;
	    $s .= uc($c);
	} else {
	    $s .= lc($c);
	}
    }

    return $s;
}

sub fetch_completions {
    my $id = shift;
    my $logger = Koha::Logger->get({ category => 'Koha.Completion.AddressServiceBorrowerCompletion'});

    my ($pnrd, $pnrn, $dob) = normalize_pnr($id);

    if (defined $pnrn) {

	my $soap = SOAP::Lite->proxy("https://adresservice.ltv.se/csp/population/LTV.AddressService.Service.GetAddressResponderBinding.cls", ssl_opts => {
	    SSL_cert_file => "/etc/ssl/certs/kovast-addressservice.cert.pem",
	    SSL_key_file => "/etc/ssl/private/kovast-addressservice.key2.pem",
	    SSL_ca_file => "/etc/ssl/certs/SITHS-cacerts.pem",
	    SSL_use_cert => 1
        });

	$soap->on_action( sub { 'ltv:population:resident:AddressService:GetAddress' } );
	$soap->ns( 'ltv:population:resident:AddressService' );

	my $resp = $soap->call('GetAddress', SOAP::Data->name('pnr')->value($pnrn));

	if ($resp->fault) {
	    my $detail = '';
	    for my $k (keys %{$resp->faultdetail->{error}}) {
		$detail .= "$k: " . $resp->faultdetail->{error}->{$k} . "\n"
	    }
	    my $msg = $resp->faultcode . ' ' . $resp->faultstring . ":\n" . $detail;
	    $logger->error($msg);
	    return { error => $msg, status => 500 };
	}

	my @form_fields = ();

	push @form_fields, {
	    'name' => 'patron_attr_',
	    'attrname' => 'PERSNUMMER',
	    'value' => $pnrd
	};
	push @form_fields, {
	    'name' => 'dateofbirth',
	    'value' => $dob	
	};

	my %map = (
	    'ENamn' => ['surname', 1],
	    'FNamn' => ['firstname', 1],
	    'PostAdress' => ['city', 1],
	    'GatuAdress' => ['address', 1],
	    'PostNr' => ['zipcode', 0],
	    'Avliden' => ['patron_attr_', 0, 'AVLIDEN'],
        );
	
	while (my ($srcname, $targetname) = each %map) {
	    if (defined($resp->result->{$srcname})) {
		my $val = $resp->result->{$srcname};
		if ($targetname->[1]) {
		    $val = name_capitalization($val);
		}
		my $record = {
		    'name' => $targetname->[0],
		    'value' => $val
		};
		if ($targetname->[0] eq 'patron_attr_') {
		    $record->{attrname} = $targetname->[2];
		}
		push @form_fields, $record;
	    }
	}

	return { form_fields => \@form_fields };
	
    } else {
	my $msg = "Felaktigt personnummer: " . $id;
	$logger->error($msg);
	return { error => $msg, status => 400 };
	
    }
}


=head1 AUTHOR

Andreas Jonsson, E<lt>andreas.jonsson@kreablo.seE<gt>

=cut

1;
