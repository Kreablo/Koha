#!/usr/bin/env perl

# This file is part of Koha, licensed under GPL version 3 or later.

use Modern::Perl;
use Test::More tests => 1;
use Test::Mojo;
use Mojo::JSON qw( true false );

use t::lib::Mocks;
use t::lib::TestBuilder;
use Koha::Database;
use Koha::Patrons;
use Koha::Patron::MessagePreference;
use Koha::Patron::MessagePreference::Attributes;
use Koha::Patron::MessagePreference::Transports;

my $schema = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );
t::lib::Mocks::mock_preference( 'IndependentBranches', 0 );

subtest 'Patron message preferences API' => sub {
    $schema->storage->txn_begin;

    my $staff = $builder->build_object(
        { class => 'Koha::Patrons', value => { flags => 2**4 } }
    );
    my $unprivileged = $builder->build_object(
        { class => 'Koha::Patrons', value => { flags => 0 } }
    );
    my $patron = $builder->build_object(
        { class => 'Koha::Patrons', value => { email => 'patron@example.org' } }
    );
    $patron->messaging_preferences->delete;

    my $password = 'Password123!';
    $_->set_password( { password => $password, skip_validation => 1 } )
        for ( $staff, $unprivileged );
    my $path = '/api/v1/patrons/' . $patron->id . '/message_preferences';
    my $url = '//' . $staff->userid . ":$password\@" . $path;
    my $forbidden = '//' . $unprivileged->userid . ":$password\@" . $path;

    # Create our own message types, independent of installed notice definitions.
    my @attrs;
    for my $takes_days ( 1, 0 ) {
        my $attr = $builder->build_object(
            {
                class => 'Koha::Patron::MessagePreference::Attributes',
                value => { takes_days => $takes_days }
            }
        );
        push @attrs, $attr;
        Koha::Patron::MessagePreference::Transport->new(
            {
                message_attribute_id => $attr->id,
                message_transport_type => 'email',
                is_digest => 0,
                letter_module => 'circulation',
                letter_code => 'TEST_MESSAGE_PREF',
                branchcode => '',
            }
        )->store;
    }

    # The replacement must preserve category defaults and other patrons.
    my $default = Koha::Patron::MessagePreference->new(
        {
            categorycode => $patron->categorycode,
            message_attribute_id => $attrs[0]->id,
            days_in_advance => 2,
            wants_digest => 0,
            message_transport_types => ['email'],
        }
    )->store;
    my $other = $builder->build_object(
        { class => 'Koha::Patrons', value => { email => 'other@example.org' } }
    );
    $other->messaging_preferences->delete;
    my $other_pref = Koha::Patron::MessagePreference->new(
        {
            borrowernumber => $other->id,
            message_attribute_id => $attrs[0]->id,
            days_in_advance => 2,
            wants_digest => 0,
            message_transport_types => ['email'],
        }
    )->store;

    $t->get_ok($path)->status_is(401);
    $t->get_ok($forbidden)->status_is(403);
    $t->put_ok( $forbidden => json => [] )->status_is(403);
    $t->get_ok($url)->status_is(200)->json_is( [] );

    my $item = {
        message_attribute_id => 0 + $attrs[0]->id,
        days_in_advance => 3,
        wants_digest => false,
        message_transport_types => ['email'],
    };
    $t->put_ok( $url => json => [$item] )->status_is(200)->json_is( [$item] );
    $t->get_ok($url)->status_is(200)->json_is( [$item] );
    my $second = {
        %$item, message_attribute_id => 0 + $attrs[1]->id, days_in_advance => undef,
    };
    my @sorted = sort { $a->{message_attribute_id} <=> $b->{message_attribute_id} } ( $item, $second );
    $t->put_ok( $url => json => [ $second, $item ] )
        ->status_is(200)->json_is( \@sorted );
    $t->put_ok( $url => json => [$item] )->status_is(200)->json_is( [$item] );
    is( $patron->messaging_preferences->count, 1, 'Omitted message types are removed' );
    $t->put_ok( $url => json => [$item] )->status_is(200)->json_is( [$item] );
    is( $patron->messaging_preferences->count, 1, 'Repeated PUT does not duplicate preferences' );

    $t->put_ok( $url => json => [ $item, $item ] )->status_is(400);
    $t->put_ok( $url => json => [ { %$item, wants_digest => true } ] )->status_is(400);
    $t->put_ok( $url => json => [ { %$item, days_in_advance => 31 } ] )->status_is(400);
    $t->put_ok( $url => json => [ { %$item, message_transport_types => ['invalid'] } ] )
        ->status_is(400);
    $t->put_ok( $url => json => [ { %$item, borrowernumber => $other->id } ] )
        ->status_is(400);

    # Fails after deleting old data and storing the first replacement row.
    my $invalid = {
        %$item,
        message_attribute_id => 0 + $attrs[1]->id,
        days_in_advance => 1, # takes_days is false for this type
    };
    my $changed = { %$item, days_in_advance => 4 };
    $t->put_ok( $url => json => [ $changed, $invalid ] )->status_is(400);
    $t->get_ok($url)->status_is(200)->json_is( [$item] );

    # An empty transport list must remove previously selected transports.
    my $no_transports = { %$item, message_transport_types => [] };
    $t->put_ok( $url => json => [$no_transports] )
        ->status_is(200)->json_is( [$no_transports] );
    my $stored = $patron->messaging_preferences->next;
    is(
        $schema->resultset('BorrowerMessageTransportPreference')->search(
            { borrower_message_preference_id => $stored->id }
        )->count,
        0, 'Transport preferences were removed'
    );
    $t->put_ok( $url => json => [] )->status_is(200)->json_is( [] );
    $t->get_ok($url)->status_is(200)->json_is( [] );

    ok( $default->get_from_storage, 'Category default preserved' );
    ok( $other_pref->get_from_storage, 'Other patron preference preserved' );

    my $missing = $builder->build_object( { class => 'Koha::Patrons' } );
    my $missing_id = $missing->id;
    $missing->delete;
    my $missing_url = '//' . $staff->userid . ":$password\@/api/v1/patrons/$missing_id/message_preferences";
    $t->get_ok($missing_url)->status_is(404);
    $t->put_ok( $missing_url => json => [] )->status_is(404);

    $schema->storage->txn_rollback;
    done_testing;
};
