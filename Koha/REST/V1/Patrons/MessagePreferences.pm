package Koha::REST::V1::Patrons::MessagePreferences;

# This file is part of Koha, licensed under GPL version 3 or later.

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw( true false );
use Scalar::Util qw( blessed );
use Try::Tiny qw( catch try );

use Koha::Database;
use Koha::Exceptions;
use Koha::Patrons;
use Koha::Patron::MessagePreference;
use Koha::Patron::MessagePreference::Transports;

=head1 NAME

Koha::REST::V1::Patrons::MessagePreferences

=head2 list

Return the patron's stored message preferences, ordered by message type.

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $patron = Koha::Patrons->find( $c->param('patron_id') );
        return $c->render_resource_not_found('Patron') unless $patron;

        return $c->render( status => 200, openapi => _preferences($patron) );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head2 overwrite

Atomically replace all stored preferences for this patron. An empty array
removes them all. Category defaults are not modified or expanded.

=cut

sub overwrite {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $patron = Koha::Patrons->find( $c->param('patron_id') );
        return $c->render_resource_not_found('Patron') unless $patron;

        my $body = $c->req->json;
        my %seen;
        foreach my $item (@$body) {
            Koha::Exceptions::BadParameter->throw(
                error => 'Each message_attribute_id may occur only once'
            ) if $seen{ $item->{message_attribute_id} }++;
        }

        my $response = Koha::Database->new->schema->txn_do(
            sub {
                # Serialize concurrent replacements made through this endpoint.
                my $locked_patron = Koha::Patrons->search(
                    { borrowernumber => $patron->id }, { for => 'update' }
                )->next;
                Koha::Exceptions::ObjectNotFound->throw(
                    error => 'Patron not found'
                ) unless $locked_patron;

                # Foreign-key ON DELETE CASCADE also removes transport preferences.
                $locked_patron->messaging_preferences->delete;

                foreach my $item (@$body) {
                    my $digest = $item->{wants_digest} ? 1 : 0;

                    # The model checks transport availability, but does not check
                    # the selected transport/digest combination in every case.
                    foreach my $type ( @{ $item->{message_transport_types} } ) {
                        my $available = Koha::Patron::MessagePreference::Transports->find(
                            {
                                message_attribute_id   => $item->{message_attribute_id},
                                message_transport_type => $type,
                                is_digest              => $digest,
                            }
                        );
                        Koha::Exceptions::BadParameter->throw(
                            error => 'Transport is unavailable for this message type and digest setting'
                        ) unless $available;
                    }

                    Koha::Patron::MessagePreference->new(
                        {
                            borrowernumber          => $locked_patron->id,
                            message_attribute_id    => $item->{message_attribute_id},
                            days_in_advance         => $item->{days_in_advance},
                            wants_digest            => $digest,
                            message_transport_types => $item->{message_transport_types},
                        }
                    )->store;
                }

                return _preferences($locked_patron);
            }
        );

        return $c->render( status => 200, openapi => $response );
    } catch {
        my $error = $_;
        if ( blessed($error) ) {
            if ( $error->isa('Koha::Exceptions::ObjectNotFound') ) {
                return $c->render_resource_not_found('Patron');
            }
            if ( $error->isa('Koha::Exceptions::BadParameter')
                || $error->isa('Koha::Exceptions::Patron::MessagePreference')
                || $error->isa('Koha::Exceptions::Patron::MessagePreference::Transport') )
            {
                return $c->render( status => 400, openapi => { error => "$error" } );
            }
        }
        $c->unhandled_exception($error);
    };
}

sub _preferences {
    my ($patron) = @_;
    my $preferences = $patron->messaging_preferences->search(
        undef, { order_by => 'message_attribute_id' }
    );
    my @result;
    while ( my $preference = $preferences->next ) {
        push @result, {
            message_attribute_id    => 0 + $preference->message_attribute_id,
            days_in_advance         => defined $preference->days_in_advance
                ? 0 + $preference->days_in_advance : undef,
            wants_digest            => $preference->wants_digest ? true : false,
            message_transport_types => [ sort keys %{ $preference->message_transport_types } ],
        };
    }
    return \@result;
}

1;
