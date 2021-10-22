package Koha::Template::Plugin::Branches;

# Copyright ByWater Solutions 2012
# Copyright BibLibre 2014

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

use Template::Plugin;
use base qw( Template::Plugin );
use Ref::Util qw( is_arrayref );

use C4::Koha;
use C4::Context;
use Koha::Cache::Memory::Lite;
use Koha::Libraries;

sub GetName {
    my ( $self, $branchcode ) = @_;
    return q{} unless defined $branchcode;
    return q{} if $branchcode eq q{};

    my $memory_cache = Koha::Cache::Memory::Lite->get_instance;
    my $cache_key    = "Library_branchname:" . $branchcode;
    my $cached       = $memory_cache->get_from_cache($cache_key);
    return $cached if $cached;

    my $l = Koha::Libraries->find($branchcode);

    my $branchname = $l ? $l->branchname : q{};
    $memory_cache->set_in_cache( $cache_key, $branchname );
    return $branchname;
}

sub GetLoggedInBranchcode {
    my ($self) = @_;

    return C4::Context::mybranch;
}

sub GetLoggedInBranchname {
    my ($self) = @_;

    return C4::Context->userenv ? C4::Context->userenv->{'branchname'} : q{};
}

sub GetURL {
    my ( $self, $branchcode ) = @_;

    unless (exists $self->{libraries}->{$branchcode} ){
        my $l = Koha::Libraries->find($branchcode);
        $self->{libraries}->{$branchcode} = $l if $l;
    }
    return $self->{libraries}->{$branchcode} ? $self->{libraries}->{$branchcode}->branchurl : q{};
}

sub all {
    my ( $self, $params ) = @_;
    my $selected = $params->{selected} // ();
    my $unfiltered = $params->{unfiltered} || 0;
    my $search_params = $params->{search_params} || {};
    my $do_not_select_my_library = $params->{do_not_select_my_library} || 0; # By default we select the library of the logged in user if no selected passed

    if ( !$unfiltered ) {
        $search_params->{only_from_group} = $params->{only_from_group} || 0;
    }

    my @selected =
      ref $selected eq 'Koha::Libraries'
      ? $selected->get_column('branchcode')
      : ( $selected // () );

    my $libraries = $unfiltered
      ? Koha::Libraries->search( $search_params, { order_by => ['branchname'] } )->unblessed
      : Koha::Libraries->search_filtered( $search_params, { order_by => ['branchname'] } )->unblessed;

    for my $l (@$libraries) {
        if ( grep { $l->{branchcode} eq $_ } @selected
            or  not @selected
                and not $do_not_select_my_library
                and C4::Context->userenv
                and $l->{branchcode} eq ( C4::Context->userenv->{branch} // q{} ) )
        {
             $l->{selected} = 1;
        }
    }


    return $libraries;
}


use Data::Dumper;

sub all_grouped {
    my ( $self, $params ) = @_;
    my $selected = $params->{selected};
    my $selecteds = $params->{selecteds};
    my $filtered = !$params->{unfiltered} || 1;
    my $userenv = C4::Context->userenv;
    my $search_params = $params->{search_params} || {};
    my $do_not_select_my_library = $params->{do_not_select_my_library} || 0; # By default we select the library of the logged in user if no selected passed

    my $pickup_location = $params->{pickup_location} || {};

    my @branchcodes = ();

    if ($filtered) {
        if ( $userenv and $userenv->{number} ) {
            my $only_from_group = $params->{only_from_group};
            if ( $only_from_group ) {
                my $logged_in_user = Koha::Patrons->find( $userenv->{number} );
                @branchcodes = $logged_in_user->libraries_where_can_see_patrons;
            } else {
                if ( C4::Context::only_my_library ) {
                    @branchcodes = (C4::Context->userenv->{branch});
                }
            }
        }
    }

    if(defined $pickup_location->{item} || defined $pickup_location->{biblio}) {
        my $item = $pickup_location->{'item'};
        my $biblio = $pickup_location->{'biblio'};
        my $patron = $pickup_location->{'patron'};
        my @libraries;

        unless (! defined $patron || ref($patron) eq 'Koha::Patron') {
            $patron = Koha::Patrons->find($patron);
        }

        if ($item) {
            $item = Koha::Items->find($item)
              unless ref($item) eq 'Koha::Item';
            @libraries = @{ $item->pickup_locations( { patron => $patron } ) }
              if defined $item;


            warn "item: " . Dumper(\@libraries);
        }
        elsif ($biblio) {
            $biblio = Koha::Biblios->find($biblio)
              unless ref($biblio) eq 'Koha::Biblio';
            @libraries = @{ $biblio->pickup_locations( { patron => $patron } ) }
              if defined $biblio;
            warn "biblio: " . Dumper(\@libraries);
        }

        map { push @branchcodes, $_->branchcode } @libraries;
    }

    
    my $where = '';
    my @binds = ();

    if (@branchcodes) {
        $where = ' WHERE branches.branchcode IN (';
        my $first = 1;
        for my $b (@branchcodes) {
            if ($first) {
                $first = 0;
            } else {
                $where .= ', ';
            }
            $where .= '?';
            push @binds, $b;
        }
        $where .= ') ';
    }
    
    while (my ($key, $value)  = each %{$params->{search_params}}) {
        next if $key eq 'patron' or $key eq 'biblio';
        if ($where eq '') {
            $where .= ' WHERE ';
        } else {
            $where .= ' AND ';
        }
        if ($key eq 'branchcode') {
            $key = 'branches.branchcode';
        }
        $where .= "$key = ?";
        push @binds, $value;
    }

    my $query = <<EOF;
    SELECT gr.title AS `group`, branches.*
    FROM branches
      LEFT OUTER JOIN library_groups AS j USING(branchcode)
      LEFT OUTER JOIN library_groups AS gr ON j.parent_id=gr.id
    $where
      ORDER BY gr.title, branchname;
EOF

    my $sth   = C4::Context->dbh->prepare($query);

    $sth->execute(@binds);

    my @selected_branchcodes = ();

    push @selected_branchcodes, $selected if defined $selected;

    if (defined $selecteds) {
        @selected_branchcodes = $selecteds ? $selecteds->get_column( ['branchcode'] ) : ();
    }

    if (!@selected_branchcodes) {
        @selected_branchcodes = (C4::Context->userenv->{branch} // '');
    }

    my $prevgroup = '';
    my $group = { name => '', libraries => [] };
    my $groups = [$group];

    while (my $row = $sth->fetchrow_hashref) {
        if (grep {$_ eq $row->{branchcode}} @selected_branchcodes
           or  not @selected_branchcodes
                and not $do_not_select_my_library
                and C4::Context->userenv
                and $row->{branchcode} eq ( C4::Context->userenv->{branch} // q{} )) {
            $row->{selected} = 1;
        } else {
            $row->{selected} = 0;
        }
        
        my $g = $row->{group} // '';
        if ($g ne $prevgroup) {
            $prevgroup = $g;
            $group = { name => $row->{group}, libraries => [] };
            push @$groups, $group;
        }
        push @{$group->{libraries}}, $row;
    }

    return $groups;
}

sub InIndependentBranchesMode {
    my ( $self ) = @_;
    return ( not C4::Context->preference("IndependentBranches") or C4::Context::IsSuperLibrarian );
}

sub pickup_locations {
    my ( $self, $params ) = @_;
    my $search_params = $params->{search_params} || {};
    my $selected      = $params->{selected};
    my @libraries;

    if ( defined $search_params->{item} || defined $search_params->{biblio} ) {
        my $item   = $search_params->{'item'};
        my $biblio = $search_params->{'biblio'};
        my $patron = $search_params->{'patron'};

        unless ( !defined $patron || ref($patron) eq 'Koha::Patron' ) {
            $patron = Koha::Patrons->find($patron);
        }

        if ($item) {
            $item = Koha::Items->find($item)
              unless ref($item) eq 'Koha::Item';
            @libraries = $item->pickup_locations( { patron => $patron } )->as_list
              if defined $item;
        } elsif ($biblio) {
            $biblio = Koha::Biblios->find($biblio)
              unless ref($biblio) eq 'Koha::Biblio';
            @libraries = $biblio->pickup_locations( { patron => $patron } )->as_list
              if defined $biblio;
        }
    } else {
        @libraries = Koha::Libraries->search( { pickup_location => 1 }, { order_by => ['branchname'] } )->as_list
          unless @libraries;
    }

    @libraries = map { $_->unblessed } @libraries;

    for my $l (@libraries) {

        # Handle DBIx::Class bug (see https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=27970).
        next if is_arrayref($l);

        if ( defined $selected and $l->{branchcode} eq $selected
            or not defined $selected
            and C4::Context->userenv
            and $l->{branchcode} eq C4::Context->userenv->{branch} )
        {
            $l->{selected} = 1;
        }
    }

    return \@libraries;
}


sub pickup_locations_grouped {
    my ($self, $params) = @_;

    return $self->all_grouped($params);
}

1;
