package Koha::REST::V1::Lists;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::Virtualshelves;

use Try::Tiny qw( catch try );

=head1 API

=head2 Methods

=head3 list_public

=cut

sub list_public {
    my $c = shift->openapi->valid_input or return;

    my $user = $c->stash('koha.user');

    my $only_mine   = $c->param('only_mine');
    my $only_public = $c->param('only_public');

    $c->req->params->remove('only_mine')->remove('only_public');

    if ( !$user && $only_mine ) {
        return $c->render(
            status  => 400,
            openapi => {
                error      => "Bad request - only_mine can only be passed by logged in users",
                error_code => "only_mine_forbidden",
            },
        );
    }

    return try {

        my $lists_set = Koha::Virtualshelves->new;

        if ($only_mine) {
            $lists_set = $lists_set->search( { owner => $user->id } );
        }

        if ( $only_public || !$user ) {
            $lists_set = $lists_set->filter_by_public;
        } else {
            $lists_set = $lists_set->filter_by_readable( { patron_id => $user->id } );
        }

        return $c->render(
            status  => 200,
            openapi => $c->objects->search($lists_set),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub create {
    my $c = shift->openapi->valid_input or return;

    my $user = $c->stash('koha.user');

    if ( !defined $user ) {
        return $c->render(
            status  => 401,
            openapi => {
                error      => "Unauthenticated",
                error_code => "unauthenticated"
            }
        );
    }

    my $public = $c->param("public") ? 1 : 0;

    if ($public) {
        my $may_create = $user->has_permission(
            'lists' => { 'create_public_lists' => 1 },
        );

        unless ($may_create) {
            return $c->render(
                status  => 403,
                openapi => {
                    error      => "Unauthorized for public list creation",
                    error_code => "unauthorized"
                }
            );
        }
    }

    my $name = $c->param("name");

    if ( defined Koha::Virtualshelves->find( { shelfname => $name } ) ) {
        return $c->render(
            status  => 409,
            openapi => {
                error      => "There is already a list with that name",
                error_code => "conflict_in_creating_resource"
            }
        );
    }

    my $shelf = Koha::Virtualshelf->new(
        {
            shelfname => $name,
            owner     => $user->id,
            public    => $public
        }
    )->store;

    return try {
        my $loc = $c->req->url->base->to_string . $c->req->url->path->to_string . "/" . $shelf->id;
        $c->res->headers->location($loc);
        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($shelf)
        );
    } catch {
        $c->unhandled_exception($_);
    }
}

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $user    = $c->stash('koha.user');
    my $list_id = $c->param("list_id");
    my $list    = Koha::Virtualshelves->find($list_id);

    return $c->render_resource_not_found("List") unless defined $list;

    if ( !defined $user ) {
        return $c->render(
            status  => 401,
            openapi => {
                error      => "Unauthenticated",
                error_code => "unauthenticated"
            }
        );
    }
    if ( !$list->can_be_deleted( $user->id ) ) {
        return $c->render(
            status  => 403,
            openapi => {
                error      => "Unauthorized",
                error_code => "unauthorized"
            }
        );
    }

    return try {
        my $deleted = $list->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    }
}

sub edit {
    my $c       = shift->openapi->valid_input or return;
    my $user    = $c->stash('koha.user');
    my $list_id = $c->param("list_id");

    my $body = $c->req->json;

    unless ( defined $user ) {
        return $c->render(
            status  => 401,
            openapi => {
                error      => "Unauthenticated",
                error_code => "unauthenticated"
            }
        );
    }

    my $list = Koha::Virtualshelves->find($list_id);

    unless ( defined $list ) {
        return $c->render(
            status  => 404,
            openapi => {
                error      => "Not found",
                error_code => "not_found"
            }
        );
    }

    unless ( $list->can_be_managed( $user->id ) ) {
        return $c->render(
            status  => 403,
            openapi => {
                error      => "Not authorized to manage this list",
                error_code => "unauthorized"
            }
        );
    }

    if ( defined $body->{public} && $body->{public} ) {
        unless ( $user->has_permission( { 'lists' => 'create_public_lists' } ) ) {
            return $c->render(
                status  => 403,
                openapi => {
                    error      => "Not authorized to change public status of this list.",
                    error_code => "unauthorized",
                }
            );
        }
    }

    return try {
        my $newlist = $list->set_from_api($body)->store;
        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($newlist),
        );
    } catch {
        $c->unhandled_exception($_);
    }
}

1;
