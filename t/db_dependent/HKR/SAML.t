#!/usr/bin/perl

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 3;
use t::lib::TestBuilder;
use t::lib::Mocks;
use Koha::Database;

require HKR::SAML;

use HKR::SAML 'MARK_ATTR';

my $schema = Koha::Database->new->schema;

subtest 'mark_patron() tests' => sub {

    $schema->storage->txn_begin;
    my $builder = t::lib::TestBuilder->new;

    my $p = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                userid => 'iB1aedah Moi1iech',
            },
        }
    );

    t::lib::Mocks::mock_preference( 'ExtendedPatronAttributes', 1 );

    $schema->resultset('BorrowerAttribute')->delete_all;
    $schema->resultset('BorrowerAttributeType')->delete_all;
    my $attr_type = $builder->build(
        {
            source => 'BorrowerAttributeType',
            value  => {
                code => MARK_ATTR,
            }
        }
    );

    ok( !HKR::SAML::patron_is_marked($p),                 'patron is not marked' );
    ok( !HKR::SAML::user_is_marked( $p->borrowernumber ), 'user is not marked' );
    ok( !HKR::SAML::userid_is_marked( $p->userid ),       'userid is not marked' );

    HKR::SAML::mark_patron($p);

    ok( HKR::SAML::patron_is_marked($p),                 'patron is marked' );
    ok( HKR::SAML::user_is_marked( $p->borrowernumber ), 'user is marked' );
    ok( HKR::SAML::userid_is_marked( $p->userid ),       'userid is marked' );

    HKR::SAML::mark_patron($p);

    is($p->extended_attributes->search({ code => HKR::SAML::MARK_ATTR() })->count, 1, 'Has exactly one attribute');

    my $attr = $p->extended_attributes->search({ code => HKR::SAML::MARK_ATTR() })->next;
    $attr->attribute('0')->store;

    ok( !HKR::SAML::patron_is_marked($p),                 'patron is not marked' );
    ok( !HKR::SAML::user_is_marked( $p->borrowernumber ), 'user is not marked' );
    ok( !HKR::SAML::userid_is_marked( $p->userid ),       'userid is not marked' );

    HKR::SAML::mark_patron($p);

    is($p->extended_attributes->search({ code => HKR::SAML::MARK_ATTR() })->count, 1, 'Has exactly one attribute');

    ok( HKR::SAML::patron_is_marked($p),                 'patron is marked' );
    ok( HKR::SAML::user_is_marked( $p->borrowernumber ), 'user is marked' );
    ok( HKR::SAML::userid_is_marked( $p->userid ),       'userid is marked' );

    $schema->storage->txn_rollback;
};

subtest 'check_consent() tests' => sub {
    $schema->storage->txn_begin;
    my $builder = t::lib::TestBuilder->new;

    my $p1 = $builder->build_object(
        {
            class => 'Koha::Patrons',
        }
    );
    my $p2 = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                password => undef,
            }
        }
    );

    t::lib::Mocks::mock_preference( 'ExtendedPatronAttributes', 1 );

    $schema->resultset('BorrowerAttribute')->delete_all;
    $schema->resultset('BorrowerAttributeType')->delete_all;
    my $attr_type = $builder->build(
        {
            source => 'BorrowerAttributeType',
            value  => {
                code => MARK_ATTR,
            }
        }
    );

    ok( !HKR::SAML::user_is_complete( $p1->borrowernumber ),     'user is not completed' );
    ok( HKR::SAML::check_user_completion( $p1->borrowernumber ), 'non-marked user is unaffected' );

    HKR::SAML::mark_patron($p2);

    ok( !HKR::SAML::check_user_completion( $p2->borrowernumber ), 'user is not completed' );

    ok( !defined $p2->password, 'user has no password' );

    ok(
        !HKR::SAML::check_and_store_consent(
            $p2,
            {
                pce_password  => '1234',
                pce_password2 => '1235',
            }
        ),
        'password mismatch'
    );

    ok( !HKR::SAML::check_user_completion( $p2->borrowernumber ), 'user is still not completed' );
    ok( !defined $p2->password,                                   'user still has no password' );

    ok(
        !HKR::SAML::check_and_store_consent(
            $p2,
            {
                pce_password  => '123',
                pce_password2 => '123',
            }
        ),
        'password too short'
    );

    ok( !HKR::SAML::check_user_completion( $p2->borrowernumber ), 'user is still not completed' );
    ok( !defined $p2->password,                                   'user still has no password' );

    ok(
        HKR::SAML::check_and_store_consent(
            $p2,
            {
                pce_password  => '1234',
                pce_password2 => '1234',
            }
        ),
        'check and store with valid password'
    );

    ok( HKR::SAML::check_user_completion( $p2->borrowernumber ), 'user is completed' );
    ok( defined $p2->password,                                   'user has password' );

    $schema->storage->txn_rollback;
    }
