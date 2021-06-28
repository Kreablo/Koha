package Personnummer;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(valid_personnummer valid_samordningsnummer normalize_personnummer);
@EXPORT_OK   = qw(normalize_personnummer_generic pnr_checksum_match);

use DateTime;
use DateTime::Format::Strptime;
use strict;

my $format = DateTime::Format::Strptime->new(
    pattern => '%y%m%d'
);

sub pnr_checksum_match ($) {
    my $s = shift;

    my $sum = 0;
    
    for (my $i = 0; $i < 9; $i++) {
        my $t = int(substr($s, $i, 1));
        my $t0 = $t * (($i + 1) % 2 + 1);
        my $t1 = 0;
        while ($t0 > 0) {
            $t1 += $t0 % 10;
            $t0 = int($t0 / 10);
        }
        $sum += $t1;
    }
    my $c = (10 - $sum % 10) % 10;
    return int(substr($s, 9, 1)) == $c;
}

sub valid_personnummer ($) {
    my $s = shift;

    if (!($s =~ /^((19)|(20))?\d{6}[-+]?\d{4}$/)) {
        return 0;
    }

    $s =~ s/[-+]//g;

    my $s0 = substr($s, (length $s) - 10);
    my $d = substr($s0, 0, 6);
    if (!defined $format->parse_datetime($d)) {
        return 0;
    }
    return pnr_checksum_match($s0);
}

sub valid_samordningsnummer($) {
    my $s = shift;

    if (!$s =~ /^((19)|(20))?\d{6}[-+]?\d{4}$/) {
        return 0;
    }

    $s =~ s/[-+]//g;

    my $s0 = substr($s, (length $s) - 10);
    my $d0 = substr($s0, 0, 6);
    my $x = int(substr($d0, 4)) - 60;
    if ($x < 0) {
        return 0;
    }
    my $d = substr($d0, 0, 4) . $x;
    if (!defined $format->parse_datetime($d)) {
        return 0;
    }
    return pnr_checksum_match($s0);
}

sub normalize_personnummer_generic ($$$$$) {
    my ($s, $ignore_invalid, $with_dash, $ten_digits, $min_age) = @_;

    if (!(valid_personnummer($s) || valid_samordningsnummer($s))) {
        if ($ignore_invalid) {
            return $s;
        } else {
            return undef;
        }
    }

    $s =~ s/[-+]//g;

    my $year;
    if (length $s == 10) {
        $year = int(substr($s, 0, 2));
        if ($year + 2000 > (DateTime->now()->year) - ($min_age - 1)) {
            $year = $year + 1900;
        } else {
            $year = $year + 2000;
        }
        $s = substr($s, 2);
    } else {
        $year = int(substr($s, 0, 4));
        $s = substr($s, 4);
    }

    my $d = substr($s, 0, 4);
    my $last = substr($s, 4);

    return '' . ($ten_digits ? substr($year, 2, 2) : $year) . $d . ($with_dash ? '-' : '') . $last;
}

sub normalize_personnummer ($) {
    my $s = shift;

    return normalize_personnummer_generic($s, 0, 0, 0, 1);
}

1;
