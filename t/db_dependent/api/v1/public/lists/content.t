#!/usr/bin/env perl

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 5;
use Test::Mojo;

use JSON qw(encode_json);

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Virtualshelves;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

$schema->storage->txn_begin;

my $password = 'thePassword123';

my $patron_1 = $builder->build_object( { class => 'Koha::Patrons' } );
my $patron_2 = $builder->build_object( { class => 'Koha::Patrons' } );

$patron_1->set_password( { password => $password, skip_validation => 1 } );
my $patron_1_userid = $patron_1->userid;

$patron_2->set_password( { password => $password, skip_validation => 1 } );
my $patron_2_userid = $patron_2->userid;

my $list_1 = $builder->build_object(
    {
        class => 'Koha::Virtualshelves', value => { owner => $patron_1->id, public => 1, allow_change_from_others => 1 }
    }
);
my $list_2 = $builder->build_object(
    {
        class => 'Koha::Virtualshelves', value => { owner => $patron_2->id, public => 0, allow_change_from_others => 0 }
    }
);

my $list_1_id = $list_1->id;
my $list_2_id = $list_2->id;

my $item_1 = $builder->build_object(
    {
        class => 'Koha::Virtualshelfcontents',
        value => { biblionumber => 123, borrowernumber => $patron_1->id, shelfnumber => $list_1->id }
    }
);
my $item_2 = $builder->build_object(
    {
        class => 'Koha::Virtualshelfcontents',
        value => { biblionumber => 234, borrowernumber => $patron_1->id, shelfnumber => $list_1->id }
    }
);
my $item_3 = $builder->build_object(
    {
        class => 'Koha::Virtualshelfcontents',
        value => { biblionumber => 321, borrowernumber => $patron_2->id, shelfnumber => $list_2->id }
    }
);
my $item_4 = $builder->build_object(
    {
        class => 'Koha::Virtualshelfcontents',
        value => { biblionumber => 432, borrowernumber => $patron_2->id, shelfnumber => $list_2->id }
    }
);

subtest 'list_contents()' => sub {

    $schema->storage->txn_begin;
    $t->get_ok( "/api/v1/public/lists/" . $list_1->id )
        ->status_is( 200, "Anonymous users can see contents of public list" );

    $t->get_ok( "/api/v1/public/lists/" . $list_2->id )
        ->status_is( 401, "Anonymous users can not see contents of private list" );

    $t->get_ok("//$patron_2_userid:$password@/api/v1/public/lists/$list_1_id")
        ->status_is( 200, "Authorized user can see public list" );

    $t->get_ok("//$patron_1_userid:$password@/api/v1/public/lists/$list_2_id")
        ->status_is( 403, "Unauthorized user can not see other users private list" );

    $schema->storage->txn_rollback;
};

subtest 'get_content()' => sub {

    $schema->storage->txn_begin;

    $t->get_ok( "/api/v1/public/lists/$list_1_id/" . $item_1->biblionumber )
        ->status_is( 200, "Anonymous users can see items from public list" )->json_is( '' => $item_1->to_api );

    $t->get_ok( "/api/v1/public/lists/$list_2_id/" . $item_3->biblionumber )
        ->status_is( 401, "Anonymous users can not see items from private list" );

    $t->get_ok( "//$patron_2_userid:$password@/api/v1/public/lists/$list_1_id/" . $item_1->biblionumber )
        ->status_is( 200, "Authorized user can see public list" )->json_is( '' => $item_1->to_api );

    $t->get_ok( "//$patron_1_userid:$password@/api/v1/public/lists/$list_2_id/" . $item_3->biblionumber )
        ->status_is( 403, "Unauthorized user can not see other users private list" );

    $t->get_ok( "//$patron_2_userid:$password@/api/v1/public/lists/$list_2_id/" . $item_3->biblionumber )
        ->status_is( 200, "Authorized user can see items in private list" )
        ->json_is( '/biblio_id' => $item_3->to_api->{biblio_id} );

    $schema->storage->txn_rollback;
};

subtest 'add_content()' => sub {

    $schema->storage->txn_begin;

    my $newbiblionumber = 251;

    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $patron_2->borrowernumber,
                module_bit     => 20,
                code           => 'edit_public_list_contents',
            },
        }
    );

    $t->put_ok( "/api/v1/public/lists/$list_1_id/" . $newbiblionumber )
        ->status_is( 401, "Anonymous users can not add items to public list" );

    $t->put_ok( "/api/v1/public/lists/$list_2_id/" . $newbiblionumber )
        ->status_is( 401, "Anonymous users can not add items to private list" );

    $t->put_ok( "//$patron_2_userid:$password@/api/v1/public/lists/$list_1_id/" . $newbiblionumber )
        ->status_is( 200, "Authorized user can add item to list" )->json_is( '/biblio_id' => $newbiblionumber );

    $t->get_ok("/api/v1/public/lists/$list_1_id")->status_is( 200, "List looks correct after modification" )
        ->json_is( "/0/biblio_id" => $item_1->biblionumber )->json_is( "/1/biblio_id" => $item_2->biblionumber )
        ->json_is( "/2/biblio_id" => $newbiblionumber );

    $schema->storage->txn_rollback;
};

subtest 'remove_content()' => sub {

    $schema->storage->txn_begin;

    $t->delete_ok( "/api/v1/public/lists/$list_1_id/" . $item_1->biblionumber )
        ->status_is( 401, "Anonymous users cannot remove items from public list" );

    $t->delete_ok( "/api/v1/public/lists/$list_2_id/" . $item_3->biblionumber )
        ->status_is( 401, "Anonymous users cannot remove itemos from private list" );

    $t->delete_ok( "//$patron_2_userid:$password@/api/v1/public/lists/$list_1_id/" . $item_1->biblionumber )
        ->status_is( 403, "Unauthorized user cannot remove item from public list" );

    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $patron_2->borrowernumber,
                module_bit     => 20,
                code           => 'edit_public_list_contents',
            },
        }
    );

    $t->delete_ok( "//$patron_2_userid:$password@/api/v1/public/lists/$list_1_id/" . $item_1->biblionumber )
        ->status_is( 204, "Authorized user can remove item from public list" );

    $t->delete_ok( "//$patron_1_userid:$password@/api/v1/public/lists/$list_2_id/" . $item_3->biblionumber )
        ->status_is( 403, "Unauthorized user cannot remove item from private list" );

    $t->get_ok( "//$patron_2_userid:$password@/api/v1/public/lists/$list_2_id/" . $item_3->biblionumber )
        ->status_is( 200, "it's still there" )->json_is( '/biblio_id' => $item_3->biblionumber );

    $schema->storage->txn_rollback;
};

$schema->storage->txn_rollback;
