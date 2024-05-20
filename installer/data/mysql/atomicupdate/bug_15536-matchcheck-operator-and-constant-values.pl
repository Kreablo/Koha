use Modern::Perl;

return {
    bug_number  => "15536",
    description => "Additional match check comparison.",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        say $out "Add column operator.";
        $dbh->do(
            q{ALTER TABLE matchchecks ADD COLUMN IF NOT EXISTS `operator` varchar(32) NOT NULL DEFAULT 'eq' AFTER `target_matchpoint_id`}
        );

        say $out "Add column constant.";
        $dbh->do(
            q{ALTER TABLE matchpoint_components ADD COLUMN IF NOT EXISTS `constant` mediumtext DEFAULT NULL AFTER `sequence`}
        );
    },
};
