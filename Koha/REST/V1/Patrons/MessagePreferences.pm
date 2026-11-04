package Koha::REST::V1::Patrons::MessagePreferences;

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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use Koha::Patrons;

use Scalar::Util qw( blessed );
use Try::Tiny    qw( catch try );

=head1 NAME

Koha::REST::V1::Patrons::MessagePreferences

=head1 API

=head2 Methods

=head3 list

Controller method that lists a patron's stored message preferences.

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    my $patron = Koha::Patrons->find( $c->param('patron_id') );

    return $c->render_resource_not_found("Patron")
        unless $patron;

    return try {
        my $preferences = $patron->messaging_preferences->search( undef, { order_by => 'message_attribute_id' } );

        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($preferences),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 overwrite

Controller method that replaces a patron's stored message preferences.

=cut

sub overwrite {
    my $c = shift->openapi->valid_input or return;

    my $patron = Koha::Patrons->find( $c->param('patron_id') );

    return $c->render_resource_not_found("Patron")
        unless $patron;

    return try {
        my $preferences =
            $patron->messaging_preferences( $c->req->json )->search( undef, { order_by => 'message_attribute_id' } );

        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($preferences),
        );
    } catch {
        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::ObjectNotFound') ) {
                return $c->render_resource_not_found("Patron");
            } elsif ( $_->isa('Koha::Exceptions::BadParameter')
                || $_->isa('Koha::Exceptions::Patron::MessagePreference')
                || $_->isa('Koha::Exceptions::Patron::MessagePreference::Transport') )
            {
                return $c->render(
                    status  => 400,
                    openapi => { error => "$_" },
                );
            }
        }

        $c->unhandled_exception($_);
    };
}

1;
