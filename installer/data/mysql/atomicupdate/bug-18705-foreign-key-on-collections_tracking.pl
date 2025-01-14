use Modern::Perl;

return {
    bug_number  => "18705",
    description => "Add foreign key on column itemnumber in collections_tracking table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{DELETE FROM collections_tracking WHERE itemnumber NOT IN (SELECT itemnumber FROM items WHERE items.itemnumber = collections_tracking.itemnumber)}
        );
        $dbh->do(q{ALTER TABLE collections_tracking ADD KEY IF NOT EXISTS `collectionst_ibfk_2` (`itemnumber`)});
        $dbh->do(
            q{ALTER TABLE collections_tracking ADD CONSTRAINT FOREIGN KEY IF NOT EXISTS  `collectionst_ibfk_2` (itemnumber) REFERENCES items (itemnumber) ON DELETE CASCADE ON UPDATE CASCADE}
        );
    },
};
