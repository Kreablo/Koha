use Modern::Perl;

return {
    bug_number => "BUG_NUMBER",
    description => "Add new system preferences RotatingCollectionReturnBranch and RotatingCollectionReturnBranchWhenOwnedByBranch",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        $dbh->do(q{INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('RotatingCollectionReturnBranch', '0', NULL, 'Do/Don''t transfer items in rotating collections to the collection''s branch when checked in.', 'YesNo') });
    },
};
