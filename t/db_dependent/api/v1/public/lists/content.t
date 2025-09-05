#!/usr/bin/env perl

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 2;
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

subtest 'list_contents()' => sub {

    # listListContents
    }

    subtest 'get_content()' => sub {

    # getListContent
    }
    subtest 'add_content()' => sub {

    # addListContent
    }
    subtest 'remove_content()' => sub {

    # removeListContent
    }
