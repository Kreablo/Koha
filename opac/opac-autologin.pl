#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright (C) 2015  Viktor Sarge
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
use CGI;
use C4::Context;
use C4::Auth qw( check_api_auth );
use Koha::Logger;

my $query = CGI->new;
my $logger = Koha::Logger->get({ interface => 'opac', category => 'opac-autologin.pl' });

my $config = C4::Context->config('opac_autologin');

if (defined $config) {
    my %usermap = ();

    for my $ui (ref $config->{item} eq 'ARRAY' ? @{$config->{item}} : ($config->{item})) {
        if (defined $ui->{ip} && defined $ui->{userid} && defined $ui->{password} && defined $ui->{target}) {
            $usermap{$ui->{ip}} = {
                'userid' => $ui->{userid},
                'password' => $ui->{password},
                'target' => $ui->{target}
            }
        } else {
            $logger->error("Invalid entry in opac_autologin configuration.");
        }
    }

    my $userinfo = $usermap{$query->remote_addr()};

    if (defined $userinfo) {
        $query->param('userid', $userinfo->{userid});
        $query->param('password', $userinfo->{password});

        my ($status, $cookie, $sessionId) = check_api_auth($query);

        warn "status: '$status'";

        if ($status eq "ok") {
            print $query->redirect(
                -uri    => $userinfo->{target},
                -cookie => $cookie,
                );
        } else {
            deny($query, $logger);
        }
    } else {
        deny($query, $logger);
    }

} else {
    deny($query, $logger);
}

sub deny {
    my $query = shift;
    my $logger = shift;
    
    print $query->header(
        -status => '403 Unauthorized'
        );
    $logger->info("Unautorized access from " . $query->remote_addr());
}
