#!/usr/bin/perl
use strict;
use warnings;

# Print newly found lines from a file

use File::Slurp;
use IO::File;

read_and_parse(shift);

sub read_and_parse
{
    my $file = shift;

    # Read in our seek file so we know where to seek to
    my $seek;
    eval { $seek = read_file( $file . '.seek' ) };

    my $fh = IO::File->new($file, "<");
    die "Error: $!" unless $fh;

    # Try to seek to the right place

    # Check if end < seek
    $fh->seek(0, SEEK_END) or die "Can't seek: $!";
    my $end = $fh->tell or die "Can't tell: $!";

    if ($end < $seek) {
        $seek = 0;
    }

    unless ($fh->seek($seek, SEEK_SET)) {
        # No go, seek to beginning
        $fh->seek(0, SEEK_SET) or die "Can't seek: $!";
    }

    while (<$fh>) {
        print ($_);
    }

    # Save seek position
    write_file( $file . '.seek', $fh->tell );

    return;
}
