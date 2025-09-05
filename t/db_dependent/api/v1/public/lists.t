#!/usr/bin/env perl

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

subtest 'list_public() tests' => sub {

    plan tests => 30;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    my $patron_1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron_2 = $builder->build_object( { class => 'Koha::Patrons' } );

    $patron_1->set_password( { password => $password, skip_validation => 1 } );
    my $patron_1_userid = $patron_1->userid;

    $patron_2->set_password( { password => $password, skip_validation => 1 } );
    my $patron_2_userid = $patron_2->userid;

    my $list_1 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_1->id, public => 1 } } );
    my $list_2 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_1->id, public => 0 } } );
    my $list_3 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_2->id, public => 1 } } );
    my $list_4 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_2->id, public => 0 } } );

    my $q = encode_json(
        {
            list_id => {
                -in => [
                    $list_1->id,
                    $list_2->id,
                    $list_3->id,
                    $list_4->id,
                ]
            }
        }
    );

    # anonymous
    $t->get_ok("/api/v1/public/lists?q=$q")->status_is( 200, "Anonymous users can only fetch public lists" )
        ->json_is( [ $list_1->to_api( { public => 1 } ), $list_3->to_api( { public => 1 } ) ] );

    $t->get_ok("/api/v1/public/lists?q=$q&only_public=1")
        ->status_is( 200, "Anonymous users can only fetch public lists" )
        ->json_is( [ $list_1->to_api( { public => 1 } ), $list_3->to_api( { public => 1 } ) ] );

    $t->get_ok("/api/v1/public/lists?q=$q&only_mine=1")
        ->status_is( 400, "Passing only_mine on an anonymous session generates a 400 code" )
        ->json_is( '/error_code' => q{only_mine_forbidden} );

    $t->get_ok("//$patron_1_userid:$password@/api/v1/public/lists?q=$q&only_mine=1")
        ->status_is( 200, "Passing only_mine with a logged in user makes it return only their lists" )
        ->json_is( [ $list_1->to_api( { public => 1 } ), $list_2->to_api( { public => 1 } ) ] );

    $t->get_ok("//$patron_2_userid:$password@/api/v1/public/lists?q=$q&only_mine=1")
        ->status_is( 200, "Passing only_mine with a logged in user makes it return only their lists" )
        ->json_is( [ $list_3->to_api( { public => 1 } ), $list_4->to_api( { public => 1 } ) ] );

    # only public
    $t->get_ok("//$patron_1_userid:$password@/api/v1/public/lists?q=$q&only_public=1")
        ->status_is( 200, "Passing only_public with a logged in user makes it return only public lists" )
        ->json_is( [ $list_1->to_api( { public => 1 } ), $list_3->to_api( { public => 1 } ) ] );

    $t->get_ok("//$patron_2_userid:$password@/api/v1/public/lists?q=$q&only_public=1")
        ->status_is( 200, "Passing only_public with a logged in user makes it return only public lists" )
        ->json_is( [ $list_1->to_api( { public => 1 } ), $list_3->to_api( { public => 1 } ) ] );

    $t->get_ok("//$patron_1_userid:$password@/api/v1/public/lists?q=$q")
        ->status_is( 200, "Not filtering with only_mine or only_public makes it return all accessible lists" )
        ->json_is(
        [ $list_1->to_api( { public => 1 } ), $list_2->to_api( { public => 1 } ), $list_3->to_api( { public => 1 } ) ]
        );

    $t->get_ok("//$patron_2_userid:$password@/api/v1/public/lists?q=$q")
        ->status_is( 200, "Not filtering with only_mine or only_public makes it return all accessible lists" )
        ->json_is(
        [ $list_1->to_api( { public => 1 } ), $list_3->to_api( { public => 1 } ), $list_4->to_api( { public => 1 } ) ]
        );

    # conflicting params
    $t->get_ok("//$patron_1_userid:$password@/api/v1/public/lists?q=$q&only_public=1&only_mine=1")
        ->status_is( 200, "Passing only_public with a logged in user makes it return only public lists" )
        ->json_is( [ $list_1->to_api( { public => 1 } ) ] );

    $schema->storage->txn_rollback;
};

subtest 'create() tests' => sub {

    # createNewList

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    my $patron_1 = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    my $patron_2 = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );

    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $patron_2->borrowernumber,
                module_bit     => 20,
                code           => 'create_public_lists',
            },
        }
    );

    $patron_1->set_password( { password => $password, skip_validation => 1 } );
    my $patron_1_userid = $patron_1->userid;

    $patron_2->set_password( { password => $password, skip_validation => 1 } );
    my $patron_2_userid = $patron_2->userid;

    $t->post_ok("//$patron_1_userid:$password@/api/v1/public/lists?name=list_1")
        ->status_is( 201, "Creating a new list is ok" );

    $t->post_ok("/api/v1/public/lists?name=list_2")->status_is( 401, "May not create without authentication" );

    $t->post_ok("//$patron_1_userid:$password@/api/v1/public/lists?name=list_3&public=true")
        ->status_is( 403, "May not create public lists without permission" );

    # probably check the returned object
    $t->post_ok("//$patron_2_userid:$password@/api/v1/public/lists?name=list_4&public=true")
        ->status_is( 201, "May create public lists with permission" );

    # and maybe what lists are in the db now

    $schema->storage->txn_rollback;
};

subtest 'edit() tests' => sub {

    # editList

    $schema->storage->txn_begin;

    our $password = 'thePassword123';

    my $patron_1 = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    my $patron_2 = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );

    $patron_1->set_password( { password => $password, skip_validation => 1 } );
    $patron_2->set_password( { password => $password, skip_validation => 1 } );

    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $patron_1->borrowernumber,
                module_bit     => 20,
                code           => 'edit_public_lists',
            },
        }
    );

    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $patron_2->borrowernumber,
                module_bit     => 20,
                code           => 'create_public_lists',
            },
        }
    );

    my $list_1 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_1->id, public => 1 } } );
    my $list_2 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_1->id, public => 0 } } );
    my $list_3 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_2->id, public => 1 } } );
    my $list_4 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_2->id, public => 0 } } );

    my $list_id1 = $list_1->id;
    my $list_id2 = $list_2->id;
    my $list_id3 = $list_3->id;
    my $list_id4 = $list_4->id;

    sub _test_uri {
        my ( $patron, $list_id ) = @_;
        return "//" . $patron->userid . ":$password@/api/v1/public/lists/" . $list_id;
    }

    $t->put_ok( "/api/v1/public/lists/$list_id2", json => { 'name' => 'new1' } )
        ->status_is( 401, "unauthenticated may not edit metadata of private list" );

    $t->put_ok( "/api/v1/public/lists/$list_id1", json => { 'name' => 'new2' } )
        ->status_is( 401, "unauthenticated may not edit metadata of public list" );

    $t->put_ok( _test_uri( $patron_2, $list_id2 ), json => { 'name' => 'new3' } )
        ->status_is( 403, "unauthorized patron may not edit private list" );

    $t->put_ok( _test_uri( $patron_2, $list_id4 ), json => { 'name' => 'new4' } )
        ->status_is( 200, "authorized patron may edit private list" );

    $t->put_ok( _test_uri( $patron_2, $list_id1 ), json => { 'name' => 'new5' } )
        ->status_is( 403, "unauthorized patron may not edit public list" );

    $t->put_ok( _test_uri( $patron_1, $list_id3 ), json => { 'name' => 'new6' } )
        ->status_is( 200, "authorized patron may edit public list" );

    $t->put_ok( _test_uri( $patron_1, $list_id2 ), json => { 'public' => 1 } )
        ->status_is( 403, "unauthorized patron may not edit public status of own list" );

    $t->put_ok( _test_uri( $patron_2, $list_id4 ), json => { 'public' => 1 } )
        ->status_is( 200, "authorized patron may edit public status of own list" );

    $t->put_ok( _test_uri( $patron_2, $list_id1 ), json => { 'public' => 0 } )
        ->status_is( 403, "patron does not have edit_public_lists permission and may not edit lists public status" );

    $t->put_ok( _test_uri( $patron_1, $list_id3 ), json => { 'public' => 0 } )
        ->status_is( 200, "authorized patron has edit_public_lists permission and may edit lists public status" );

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    # deleteList
    $schema->storage->txn_begin;

    our $password = 'thePassword123';

    my $patron_1 = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    my $patron_2 = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );

    $patron_1->set_password( { password => $password, skip_validation => 1 } );
    my $patron_1_userid = $patron_1->userid;
    $patron_2->set_password( { password => $password, skip_validation => 1 } );
    my $patron_2_userid = $patron_2->userid;

    my $list_1 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_1->id, public => 1 } } );
    my $list_2 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_1->id, public => 0 } } );
    my $list_3 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_2->id, public => 1 } } );
    my $list_4 =
        $builder->build_object( { class => 'Koha::Virtualshelves', value => { owner => $patron_2->id, public => 0 } } );

    my $list_id1 = $list_1->id;
    my $list_id2 = $list_2->id;
    my $list_id3 = $list_3->id;
    my $list_id4 = $list_4->id;

    my $q = encode_json(
        {
            list_id => {
                -in => [
                    $list_1->id,
                    $list_2->id,
                    $list_3->id,
                    $list_4->id,
                ]
            }
        }
    );

    $t->delete_ok("/api/v1/public/lists/$list_id2")->status_is( 401, "Unathenticated may not remove private list" );
    $t->delete_ok("/api/v1/public/lists/$list_id3")->status_is( 401, "Unathenticated may not remove public list" );

    $t->delete_ok("//$patron_1_userid:$password@/api/v1/public/lists/$list_id2")
        ->status_is( 204, "Authenticated may remove private list" );
    $t->delete_ok("//$patron_2_userid:$password@/api/v1/public/lists/$list_id3")
        ->status_is( 204, "Authenticated may remove public list" );

    $t->delete_ok("//$patron_1_userid:$password@/api/v1/public/lists/$list_id4")
        ->status_is( 403, "Unauthorized may not remove private list" );
    $t->delete_ok("//$patron_2_userid:$password@/api/v1/public/lists/$list_id1")
        ->status_is( 403, "Unauthorized may not remove public list" );

    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $patron_2->borrowernumber,
                module_bit     => 20,
                code           => 'delete_public_lists',
            },
        }
    );

    $t->delete_ok("//$patron_2_userid:$password@/api/v1/public/lists/$list_id1")
        ->status_is( 204, "Authorized may remove public list" );

    # test list state here.

    $schema->storage->txn_rollback;
};
