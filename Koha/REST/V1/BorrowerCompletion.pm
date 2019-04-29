package Koha::REST::V1::BorrowerCompletion;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use DateTime;
use DateTime::Format::Builder;
use DateTime::Format::Strptime;
use Koha::DateUtils;

sub fetch {
    my $c = shift->openapi->valid_input or return;
    my $dateformat = C4::Context->preference('dateformat');

    
    my $parser = DateTime::Format::Strptime->new(
	pattern => '%F',
	);


    return $c->render( status => 200,
		       openapi => {
			   form_id => "entryform",
			   form_fields => [
			       {
				   "name" => "surname",
				   "value" => "Enarsson"
			       },
			       {
				   "name" => "firstname",
			           "value" => "Enea"
			       },
			       {
				   "name" => "dateofbirth",
				   "value" => output_pref($parser->parse_datetime("2001-01-01"))
			       },
			       {
				   "name" => "address",
			           "value" => "Engatan 42"
			       },
			       {
				   "name" => "city",
			           "value" => "Enstad"
			       },
			       {
				   "name" => "phone",
			           "value" => "+46712345567"
			       }
			       ]
		       }
	);
}

1;
