package HKR::SAML;

use Exporter 'import';
our @EXPORT_OK = qw(
    mark_patron
    patron_is_marked
    MARK_ATTR
);

use constant {
    MARK_ATTR => 'SAML_USER',
};

sub mark_patron {
    my ($patron) = shift;

    if (!patron_is_marked($patron)) {
        $patron->add_extended_attribute({
            code => MARK_ATTR,
            attribute => 1,
        });
    }
}

sub patron_is_marked {
    my $patron = shift;

    if (!$patron) {
        return 0;
    }

    my $attr = $patron->get_extended_attribute(MARK_ATTR);
    if (!defined $attr) {
        return 0;
    }

    return $attr->attribute;
}
