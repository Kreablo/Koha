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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 7;
use Test::Exception;
use Test::Mojo;

use Mojo::JSON qw( true false );
use Storable   qw( dclone );

use t::lib::Mocks;
use t::lib::TestBuilder;

use Koha::Database;
use Koha::Patrons;
use Koha::Patron::MessagePreference;
use Koha::Patron::MessagePreference::Attributes;
use Koha::Patron::MessagePreference::Transports;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $t       = Test::Mojo->new('Koha::REST::V1');

t::lib::Mocks::mock_preference( 'RESTBasicAuth',       1 );
t::lib::Mocks::mock_preference( 'IndependentBranches', 0 );

subtest 'Authorization' => sub {
    $schema->storage->txn_begin;
    my $fixture = fixture();

    $t->get_ok( $fixture->{path} )->status_is(401);
    $t->put_ok( $fixture->{path} => json => [] )->status_is(401);
    $t->get_ok( $fixture->{forbidden} )->status_is(403);
    $t->put_ok( $fixture->{forbidden} => json => [] )->status_is(403);

    $schema->storage->txn_rollback;
    done_testing;
};

subtest 'list()' => sub {
    $schema->storage->txn_begin;
    my $fixture = fixture();
    my $patron  = $fixture->{patron};
    my $url     = $fixture->{url};
    my $item    = $fixture->{item};
    my $second  = $fixture->{second};

    $t->get_ok($url)->status_is(200)->json_is( [] );

    $patron->messaging_preferences( [ $second, $item ] );
    my @expected = sort { $a->{message_attribute_id} <=> $b->{message_attribute_id} } ( $item, $second );
    $t->get_ok($url)->status_is(200)->json_is( \@expected );
    $t->get_ok( $fixture->{missing} )->status_is(404);

    $schema->storage->txn_rollback;
    done_testing;
};

subtest 'overwrite()' => sub {
    $schema->storage->txn_begin;
    my $fixture = fixture();
    my $patron  = $fixture->{patron};
    my $url     = $fixture->{url};
    my $item    = $fixture->{item};
    my $second  = $fixture->{second};

    $t->put_ok( $url => json => [$item] )->status_is(200)->json_is( [$item] );
    $t->get_ok($url)->status_is(200)->json_is( [$item] );

    my @expected = sort { $a->{message_attribute_id} <=> $b->{message_attribute_id} } ( $item, $second );
    $t->put_ok( $url => json => [ $second, $item ] )->status_is(200)->json_is( \@expected );
    $t->put_ok( $url => json => [$item] )->status_is(200)->json_is( [$item] );
    is( $patron->messaging_preferences->count, 1, 'Omitted message types are removed' );

    $t->put_ok( $url => json => [$item] )->status_is(200)->json_is( [$item] );
    is( $patron->messaging_preferences->count, 1, 'Repeated PUT does not duplicate preferences' );

    my $digest = { %$item, wants_digest => true };
    $t->put_ok( $url => json => [$digest] )->status_is(200)->json_is( [$digest] );

    my $no_transports = { %$item, message_transport_types => [] };
    $t->put_ok( $url => json => [$no_transports] )->status_is(200)->json_is( [$no_transports] );
    my $stored = $patron->messaging_preferences->next;
    is(
        $schema->resultset('BorrowerMessageTransportPreference')
            ->search( { borrower_message_preference_id => $stored->id } )
            ->count,
        0, 'Previously selected transport preferences were removed'
    );

    $t->put_ok( $url => json => [] )->status_is(200)->json_is( [] );
    $t->get_ok($url)->status_is(200)->json_is( [] );
    ok( $fixture->{default}->get_from_storage,    'Category default preserved' );
    ok( $fixture->{other_pref}->get_from_storage, 'Other patron preference preserved' );
    $t->put_ok( $fixture->{missing} => json => [] )->status_is(404);

    $schema->storage->txn_rollback;
    done_testing;
};

subtest 'Validation' => sub {
    $schema->storage->txn_begin;
    my $fixture = fixture();
    my $url     = $fixture->{url};
    my $item    = $fixture->{item};
    my $second  = $fixture->{second};

    $fixture->{patron}->messaging_preferences( [$item] );

    $t->put_ok( $url => json => [ $item, $item ] )->status_is(400);
    $t->put_ok( $url => json => [ { %$second, wants_digest            => true } ] )->status_is(400);
    $t->put_ok( $url => json => [ { %$item,   days_in_advance         => 31 } ] )->status_is(400);
    $t->put_ok( $url => json => [ { %$item,   message_transport_types => ['invalid'] } ] )->status_is(400);
    $t->put_ok( $url => json => [ { %$item,   message_transport_types => [ 'email', 'email' ] } ] )->status_is(400);
    $t->put_ok( $url => json => [ { %$item,   borrowernumber          => $fixture->{other}->id } ] )->status_is(400);

    my %incomplete = %$item;
    delete $incomplete{wants_digest};
    $t->put_ok( $url => json => [ \%incomplete ] )->status_is(400);
    $t->get_ok($url)->status_is(200)->json_is( [$item] );

    $schema->storage->txn_rollback;
    done_testing;
};

subtest 'Rollback' => sub {
    $schema->storage->txn_begin;
    my $fixture = fixture();
    my $url     = $fixture->{url};
    my $item    = $fixture->{item};

    $fixture->{patron}->messaging_preferences( [$item] );

    # The second preference fails after the first replacement has been stored.
    my $changed = { %$item, days_in_advance => 4 };
    my $invalid = { %{ $fixture->{second} }, days_in_advance => 1 };
    $t->put_ok( $url => json => [ $changed, $invalid ] )->status_is(400);
    $t->get_ok($url)->status_is(200)->json_is( [$item] );

    $schema->storage->txn_rollback;
    done_testing;
};

subtest 'messaging_preferences() and to_api()' => sub {
    $schema->storage->txn_begin;
    my $fixture = fixture();
    my $patron  = $fixture->{patron};
    my $item    = $fixture->{item};
    my $input   = [$item];
    my $before  = dclone($input);

    isa_ok( $patron->messaging_preferences, 'Koha::Patron::MessagePreferences' );
    my $preferences = $patron->messaging_preferences($input);
    isa_ok( $preferences, 'Koha::Patron::MessagePreferences' );
    is_deeply( $input,                                 $before, 'Setter does not modify its input' );
    is_deeply( $preferences->next->to_api,             $item,   'Model supplies the complete API representation' );
    is_deeply( $patron->messaging_preferences->to_api, [$item], 'Getter remains compatible' );

    throws_ok {
        $patron->messaging_preferences( [ $item, $item ] );
    }
    'Koha::Exceptions::BadParameter', 'Model rejects duplicate message types';

    my $invalid = { %{ $fixture->{second} }, days_in_advance => 1 };
    throws_ok {
        $patron->messaging_preferences( [ { %$item, days_in_advance => 4 }, $invalid ] );
    }
    'Koha::Exceptions::Patron::MessagePreference::DaysInAdvanceNotAvailable',
        'Model rejects days when the message type does not support them';
    is_deeply( $patron->messaging_preferences->to_api, [$item], 'Model rolls back failed replacement' );

    throws_ok {
        $patron->messaging_preferences( {} );
    }
    'Koha::Exceptions::BadParameter', 'Setter requires an array reference';

    $patron->messaging_preferences( [] );
    is( $patron->messaging_preferences->count, 0, 'Empty array clears preferences through the model' );

    $schema->storage->txn_rollback;
    done_testing;
};

sub fixture {
    my $staff        = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**4 } } );
    my $unprivileged = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { email => 'patron@example.org' } } );
    $patron->messaging_preferences->delete;

    my $password = 'Password123!';
    $_->set_password( { password => $password, skip_validation => 1 } ) for ( $staff, $unprivileged );
    my $path      = '/api/v1/patrons/' . $patron->id . '/message_preferences';
    my $auth      = '//' . $staff->userid . ":$password\@";
    my $forbidden = '//' . $unprivileged->userid . ":$password\@" . $path;

    my @attrs;
    foreach my $takes_days ( 1, 0 ) {
        my $attr = $builder->build_object(
            {
                class => 'Koha::Patron::MessagePreference::Attributes',
                value => { takes_days => $takes_days },
            }
        );
        push @attrs, $attr;
        my @digests = $takes_days ? ( 0, 1 ) : (0);
        foreach my $digest (@digests) {
            Koha::Patron::MessagePreference::Transport->new(
                {
                    message_attribute_id   => $attr->id,
                    message_transport_type => 'email',
                    is_digest              => $digest,
                    letter_module          => 'circulation',
                    letter_code            => 'TEST_MESSAGE_PREF',
                    branchcode             => '',
                }
            )->store;
        }
    }

    my $item = {
        message_attribute_id    => 0 + $attrs[0]->id,
        days_in_advance         => 3,
        wants_digest            => false,
        message_transport_types => ['email'],
    };
    my $second  = { %$item, message_attribute_id => 0 + $attrs[1]->id, days_in_advance => undef };
    my $default = Koha::Patron::MessagePreference->new(
        {
            categorycode            => $patron->categorycode,
            message_attribute_id    => $attrs[0]->id,
            days_in_advance         => 2,
            wants_digest            => 0,
            message_transport_types => ['email'],
        }
    )->store;
    my $other = $builder->build_object( { class => 'Koha::Patrons', value => { email => 'other@example.org' } } );
    $other->messaging_preferences->delete;
    my $other_pref = Koha::Patron::MessagePreference->new(
        {
            borrowernumber          => $other->id,
            message_attribute_id    => $attrs[0]->id,
            days_in_advance         => 2,
            wants_digest            => 0,
            message_transport_types => ['email'],
        }
    )->store;

    my $missing    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $missing_id = $missing->id;
    $missing->delete;

    return {
        patron     => $patron,
        other      => $other,
        default    => $default,
        other_pref => $other_pref,
        item       => $item,
        second     => $second,
        path       => $path,
        url        => $auth . $path,
        forbidden  => $forbidden,
        missing    => $auth . "/api/v1/patrons/$missing_id/message_preferences",
    };
}
