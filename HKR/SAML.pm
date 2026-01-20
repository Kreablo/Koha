package HKR::SAML;

use strict;

use Koha::AuthUtils;
use Koha::Patron::Consents;
use Koha::DateUtils qw( dt_from_string );
use Koha::Object;

use Exporter 'import';

our @EXPORT_OK = qw(
    mark_patron
    patron_is_marked
    user_is_marked
    check_and_store_consent
    check_user_completion
    MARK_ATTR
    CONSENT_TYPE
);

use constant {
    MARK_ATTR    => 'SAML_USER',
    CONSENT_TYPE => 'SAML_EXTRA_CONSENT',
};

sub mark_patron {
    my ($patron) = shift;

    if ( !patron_is_marked($patron) ) {
        my $attr = $patron->extended_attributes->search({ code => HKR::SAML::MARK_ATTR() })->next;
        if ($attr) {
            $attr->attribute(1);
            $attr->store;
        } else {
            $patron->add_extended_attribute(
                {
                    code      => MARK_ATTR,
                    attribute => 1,
                }
            );
        }
    }
}

sub patron_is_marked {
    my $patron = shift;

    if ( !$patron ) {
        return 0;
    }

    my $attr = $patron->get_extended_attribute(MARK_ATTR);
    if ( !defined $attr ) {
        return 0;
    }

    return $attr->attribute;
}

sub user_is_marked {
    my $borrowernumber = shift;

    my $attr = Koha::Patron::Attributes->search(
        {
            borrowernumber => $borrowernumber,
            code           => MARK_ATTR,
        }
    );

    return $attr->count > 0 && $attr->next->attribute;
}

sub userid_is_marked {
    my $userid = shift;

    my $attr = Koha::Patron::Attributes->search(
        {
            userid => $userid,
            code   => MARK_ATTR,
        },
        {
            join => 'borrowernumber',
        }
    );

    return $attr->count > 0 && $attr->next->attribute;
}

sub _consent {
    my $borrowernumber = shift;

    my $consent = Koha::Patron::Consents->search(
        {
            borrowernumber => $borrowernumber,
            type           => HKR::SAML::CONSENT_TYPE(),
            given_on       => { '!=', undef },
        }
    )->next;

    return $consent;
}

sub _consent_valid {
    my $consent = shift;

    return defined $consent && defined $consent->given_on;
}

sub user_is_complete {
    my $borrowernumber = shift;

    my $consent = _consent($borrowernumber);

    return _consent_valid($consent);
}

sub _set_patron_complete {
    my $patron = shift;

    my $consent = $patron->consent( HKR::SAML::CONSENT_TYPE() );
    $consent->set(
        {
            given_on => dt_from_string(),
        }
    )->store;
}

sub _set_password {
    my $patron   = shift;
    my $password = shift;

    my $digest = Koha::AuthUtils::hash_password($password);

    $patron->password_expiration_date( $patron->category->get_password_expiry_date || undef );

    # We do not want to call $patron->store and retrieve password from DB
    $patron->password($digest);
    $patron->login_attempts(0);
    Koha::Object::store($patron);
}

sub check_user_completion {
    my $borrowernumber = shift;

    return !user_is_marked($borrowernumber) || ( user_is_marked($borrowernumber) && user_is_complete($borrowernumber) );
}

sub check_and_store_consent {
    my $patron = shift;
    my $vars   = shift;

    if ( !patron_is_marked($patron) ) {
        return 1;
    }

    my $consent = _consent( $patron->borrowernumber );

    if ( _consent_valid($consent) ) {
        return 1;
    }

    my $pw1 = $vars->{pce_password};
    my $pw2 = $vars->{pce_password2};

    if ( length $pw1 >= 4 && $pw1 eq $pw2 ) {
        _set_password( $patron, $pw1 );
        _set_patron_complete($patron);
        return 1;
    }

    return 0;
}
