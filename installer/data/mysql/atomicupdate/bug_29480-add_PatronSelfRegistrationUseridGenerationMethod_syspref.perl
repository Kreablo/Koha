$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {

        $dbh->do(<<'EOF');
INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES
('PatronSelfRegistrationUseridGenerationMethod', 'default', 'default|email', 'Method for generating userid of of a borrower when self registering in OPAC.  Fallback to generating a userid from the name of the borrower.', '');
EOF

    # Always end with this (adjust the bug info)
    NewVersion( $DBversion, 29480, "Add new system preference PatronSelfRegistrationUseridGenerationMethod");
}
