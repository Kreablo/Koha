package Koha::REST::V1::Lists::Content;

use Mojo::Base 'Mojolicious::Controller';

use Koha::Virtualshelves;
use Koha::Virtualshelfcontents;

use Try::Tiny qw( catch try );

sub list_contents {
    my $c = shift->openapi->valid_input or return;

    my $user    = $c->stash('koha.user');
    my $list_id = $c->param("list_id");
    my $list    = Koha::Virtualshelves->find($list_id);
    $c->req->params->remove("list_id");

    unless ( defined $list ) {
        return $c->render(
            status  => 404,
            openapi => {
                error      => "Not found",
                error_code => "not_found"
            }
        );
    }
    unless ( $list->public ) {
        if ( !defined $user ) {
            return $c->render(
                status  => 401,
                openapi => {
                    error      => "Unauthenticated",
                    error_code => "unauthenticated"
                }
            );
        } elsif ( !$list->can_be_viewed( $user->id ) ) {
            return $c->render(
                status  => 403,
                openapi => {
                    error      => "Unauthorized",
                    error_code => "unauthorized"
                }
            );
        }
    }

    return try {
        $c->res->headers->location( $c->req->url->to_string );
        return $c->render(
            status  => 200,
            openapi => $list->get_contents->to_api
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub get_content {
    my $c = shift->openapi->valid_input or return;

    my $user      = $c->stash('koha.user');
    my $list_id   = $c->param("list_id");
    my $biblio_id = $c->param("biblio_id");

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
    unless ( $list->public ) {
        if ( !defined $user ) {
            return $c->render(
                status  => 401,
                openapi => {
                    error      => "Unauthenticated",
                    error_code => "unauthenticated"
                }
            );
        } elsif ( $list->owner != $user->id ) {
            return $c->render(
                status  => 403,
                openapi => {
                    error      => "Unauthorized",
                    error_code => "unauthorized"
                }
            );
        }
    }

    my $item = Koha::Virtualshelfcontents->find(
        {
            shelfnumber  => $list_id,
            biblionumber => $biblio_id
        }
    );

    return $c->render_resource_not_found("Item") unless defined $item;

    return try {
        $c->res->headers->location( $c->req->url->to_string );
        return $c->render(
            status  => 200,
            openapi => $item->to_api
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub add_content {
    my $c         = shift->openapi->valid_input or return;
    my $user      = $c->stash('koha.user');
    my $list_id   = $c->param("list_id");
    my $biblio_id = $c->param("biblio_id");

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
    unless ( $list->can_biblios_be_added( $user->id ) ) {
        return $c->render(
            status  => 403,
            openapi => {
                error      => "Not authorized to add biblios to this list",
                error_code => "unauthorized"
            }
        );
    }

    return try {
        my $newlist = $list->add_biblio( $biblio_id, $user->id );

        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($newlist)
        );
    } catch {
        $c->unhandled_exception($_);
    }
}

sub remove_content {
    my $c = shift->openapi->valid_input or return;

    my $user      = $c->stash('koha.user');
    my $list_id   = $c->param("list_id");
    my $biblio_id = $c->param("biblio_id");

    my $list = Koha::Virtualshelves->find($list_id);

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

    if ( !$list->can_biblios_be_removed( $user->id ) ) {
        return $c->render(
            status  => 403,
            openapi => {
                error      => "Unauthorized",
                error_code => "unauthorized"
            }
        );
    }

    return try {
        my $removed = $list->remove_biblios(
            {
                biblionumbers  => [$biblio_id],
                borrowernumber => $user->id
            }
        );

        if ( $removed > 0 ) {
            return $c->render_resource_deleted;
        }
        return $c->render(
            status  => 400,
            openapi => {
                error      => "Nothing to remove",
                error_code => "bad_request"
            }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
