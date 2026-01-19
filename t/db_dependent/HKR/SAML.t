#!/usr/bin/perl

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 2;
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
        }
    );

    t::lib::Mocks::mock_preference( 'ExtendedPatronAttributes', 1 );

    $schema->resultset('BorrowerAttribute')->delete_all;
    $schema->resultset('BorrowerAttributeType')->delete_all;
    my $attr_type = $builder->build(
        {
            source => 'BorrowerAttributeType',
            value  => {
                code                      => MARK_ATTR,
            }
        }
    );

    ok(!HKR::SAML::patron_is_marked($p, 'patron is not marked'));

    HKR::SAML::mark_patron($p);

    ok(HKR::SAML::patron_is_marked($p, 'patron is marked'));

    $schema->storage->txn_rollback;
};
