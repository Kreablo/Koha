#!/usr/bin/perl
#
# This file is part of Koha.
#
# Copyright (C) 2018  Andreas Jonsson <andreas.jonsson@kreablo.se>
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

use Test::More tests => 12;
use t::lib::TestBuilder;
use DateTime;
use File::Spec;
use File::Basename;
use Data::Dumper;

my $scriptDir = dirname(File::Spec->rel2abs( __FILE__ ));

my $dbh = C4::Context->dbh;

# Set only to avoid exception.
$ENV{"OVERRIDE_SYSPREF_dateformat"} = 'metric';

$ENV{"OVERRIDE_SYSPREF_PrintNoticesMaxLines"} = 1000;
$ENV{"OVERRIDE_SYSPREF_delimiter"} = ';';
$ENV{"OVERRIDE_SYSPREF_OverdueNoticeCalendar"} = 0;
$ENV{"OVERRIDE_SYSPREF_AutoEmailPrimaryAddress"} = 'email';

$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

my $builder = t::lib::TestBuilder->new;

my $library1 = $builder->build({
    source => 'Branch',
    value => {
	branchcode => 'library1'
    }
});

my $category = $builder->build({
    source => 'Category',
    value => {
	categorycode => 'PATRON',
	overduenoticerequired => 1
    }
});

my @borrowers = map {
    my $value =  {
            branchcode => $library1->{branchcode},
	    categorycode => 'PATRON',
	    smsalertnumber => '',
	    email => '',
	    emailpro => '',
	    B_email => '',
    };
    if ($_ == 0) {
	$value->{email} = 'borrower@example.com',
        $value->{smsalertnumber} = '555'
    } elsif ($_ == 1) {
	$value->{email} = 'borrower@example.com'
    } elsif ($_ == 2) {
	$value->{smsalertnumber} = '555'
    }
    $builder->build({
        source => 'Borrower',
        value => $value
    });
} (0, 1, 2, 3);

my $message_attribute = $builder->build({
    source => 'MessageAttribute',
    value => {
	message_name => 'advance_notice'
    }
});

my $letter_email = $builder->build({
    source => 'Letter',
    value => {
        module => 'circulation',
        code => 'ODUE',
        branchcode => '',
        message_transport_type => 'email',
        lang => 'default',
        is_html => 0,
        content => 'ODUE email'
    }
});

my $letter_print = $builder->build({
    source => 'Letter',
    value => {
        module => 'circulation',
        code => 'ODUE',
        branchcode => '',
        message_transport_type => 'print',
        lang => 'default',
        is_html => 0,
        content => 'ODUE print <<borrowers.borrowernumber>>'
    }
});

my $letter_sms = $builder->build({
    source => 'Letter',
    value => {
        module => 'circulation',
        code => 'ODUE',
        branchcode => '',
        message_transport_type => 'sms',
        lang => 'default',
        is_html => 0,
        content => 'ODUE sms'
    }
});

my $now = DateTime->now();
my $yesterday = $now->add(days => -1)->strftime('%F');

my $biblio = $builder->build({
    source => 'Biblio',
});
my $biblioitem = $builder->build({
    source => 'Biblioitem',
    value => {
        biblionumber => $biblio->{biblionumber}
    }
});

my @items = map {
    $builder->build({
	source => 'Item',
	value => {
	    itemlost => 0,
	    biblionumber => $biblio->{biblionumber}
	}
    });
} (0, 1, 2, 3);

my @issues = map {
    $builder->build({
	source => 'Issue',
	value => {
	    date_due => $yesterday,
	    itemnumber => $items[$_]->{itemnumber},
	    branchcode => $library1->{branchcode},
	    borrowernumber => $borrowers[$_]->{borrowernumber},
	    returndate => undef
	}
    });
} (0, 1, 2, 3);


my @borrower_message_preferences = map {
    my $mp = $builder->build({
	source => 'BorrowerMessagePreference',
	value => {
	    borrowernumber => $borrowers[$_]->{borrowernumber},
	    message_attribute_id => $message_attribute->{message_attribute_id}
	}
    });
    $builder->build({
	source => 'BorrowerMessageTransportPreference',
	value => {
	    borrower_message_preference_id => $mp->{borrower_message_preference_id},
	    message_transport_type => 'email'
	}
    });
    $builder->build({
	source => 'BorrowerMessageTransportPreference',
	value => {
	    borrower_message_preference_id => $mp->{borrower_message_preference_id},
	    message_transport_type => 'sms'
	}
    });
    $mp;
} (0, 1, 2, 3);

my $overdue_rule = $builder->build({
    source => 'Overduerule',
    value => {
	branchcode => $library1->{branchcode},
	delay1 => 1,
	letter1 => 'ODUE',
	delay2 => 2,
	delay3 => 3,
	debarred1 => 0,
	categorycode => 'PATRON',
    }
});


my $overdue_rule_transport_type_email = $builder->build({
    source => 'OverduerulesTransportType',
    value => {
	overduerules_id => $overdue_rule->{overduerules_id},
	letternumber => 1,
	message_transport_type => 'email'
    }
});

#my $overdue_rule_transport_type_print = $builder->build({
#    source => 'OverduerulesTransportType',
#    value => {
#	overduerules_id => $overdue_rule->{overduerules_id},
#	letternumber => 1,
#	message_transport_type => 'print'
#    }
#});

my $overdue_rule_transport_type_sms = $builder->build({
    source => 'OverduerulesTransportType',
    value => {
	overduerules_id => $overdue_rule->{overduerules_id},
	letternumber => 1,
	message_transport_type => 'sms'
    }
});

my $script = '';
my $scriptFile = "$scriptDir/../../../misc/cronjobs/overdue_notices.pl";
open SCRIPT, "<", $scriptFile or die "Failed to open $scriptFile: $!";

while (<SCRIPT>) {
    $script .= $_;
}
close SCRIPT;

@ARGV = ('overdue_notices.pl', '-t');

eval $script;
die $@ if $@;

my $sthmq = $dbh->prepare('SELECT * FROM message_queue');
$sthmq->execute();

my $messages = $sthmq->fetchall_hashref('message_id');

is(scalar(keys %$messages), 8, 'The message queue contains 8 messages');

my %expected_messagetypes = (
    $borrowers[0]->{borrowernumber} => ['sms', 'email'],
    $borrowers[1]->{borrowernumber} => ['email', 'print'],
    $borrowers[2]->{borrowernumber} => ['sms', 'print'],
    $borrowers[3]->{borrowernumber} => ['print']
);

for my $m (values %$messages) {
    if ($m->{borrowernumber} eq '') {
	my ($b0, $b1, $b2, $b3) = (0, 0, 0, 0);
	my $c = $m->{content};
	while ($c =~ m/ODUE print $borrowers[0]->{borrowernumber}/g) {
	    $b0++;
	}
	while ($c =~ m/ODUE print $borrowers[1]->{borrowernumber}/g) {
	    $b1++;
	}
	while ($c =~ m/ODUE print $borrowers[2]->{borrowernumber}/g) {
	    $b2++;
	}
	while ($c =~ m/ODUE print $borrowers[3]->{borrowernumber}/g) {
	    $b3++;
	}
	is ($b0, 0, 'No notice for borrower 0');
	is ($b1, 1, '1 notice for borrower 1');
	is ($b2, 1, '1 notice for borrower 2');
	is ($b3, 2, '2 notices for borrower 3');
    } else {
	my $mts = $expected_messagetypes{$m->{borrowernumber}};
	my $i = -1;
	my $j = 0;
	for my $mt (@$mts) {
	    if ($mt eq $m->{message_transport_type}) {
		$i = $j;
		last;
	    }
	    $j++;
	}
	if ($i >= 0) {
	    splice @$mts, $i, 1;
	}
	ok ($i >= 0, "Message have expected transport type for borrower " . $m->{borrowernumber});
    }
}

$dbh->rollback;

1;
