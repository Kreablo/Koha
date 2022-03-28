use Modern::Perl;
 
return {
    bug_number => "BUG_NUMBER",
    description => "Add new system preference SIPUseSameUserID",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
 
        $dbh->do(q{INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('SIPUseSameUserID', '0', '', 'Return the same user identity in SIP reply as was sent in the sip request to identify the patron.', 'YesNo') });
    },
};
