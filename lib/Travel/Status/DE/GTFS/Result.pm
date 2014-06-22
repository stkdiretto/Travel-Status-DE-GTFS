package Travel::Status::DE::GTFS::Result;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

Travel::Status::DE::GTFS::Result->mk_ro_accessors(
	qw(countdown date destination key line lineref
	  platform platform_name sched_date sched_time time type)
);

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	return bless( $ref, $obj );
}

sub TO_JSON {
	my ($self) = @_;

	return { %{$self} };
}


=head1 NAME

Travel::Status::DE::GTFS::Result - Information about a single
departure received by Travel::Status::DE::GTFS

=head1 SYNOPSIS

    # print all departures
    for my $departure ($status->results) {
        printf(
            "At %s: %s to %s from platform %d\n",
            $departure->time, $departure->line, $departure->destination,
            $departure->countdown
        );
    }
    
    # print only departures occurring after the current time
    for my $departure ($status->results(purge => 1)) {
        printf(
            "At %s: %s to %s from platform %d\n",
            $departure->time, $departure->line, $departure->destination,
            $departure->countdown
        );
    }


=head1 VERSION

version 0.01

=cut
our $VERSION = '0.01';


=head1 DESCRIPTION

Travel::Status::DE::GTFS::Result describes a single departure as obtained by
Travel::Status::DE::GTFS.  It contains information about the time, platform,
line number and destination.

=head1 METHODS

=head2 ACCESSORS

=over

=item $departure->countdown

Time in minutes from now until the tram/bus/train will depart as per schedule.

=item $departure->destination

Headsign destination name.

=item $departure->key

The trip_id from the GTFS feed for the current departure.

=item $departure->line

The name/number of the line. This will be route_short_name if it is set and not an empty string; route_long_name otherwise.

=item $departure->lineref

Travel::Status::DE::GTFS::Line(3pm) object describing the departing line in
detail.

=item $departure->platform

Departure platform number (may not be a number).

=item $departure->sched_date

Scheduled departure date (DD.MM.YYYY).

=item $departure->sched_time

Scheduled departure time (HH:MM:SS).

=item $departure->type

Type of the departure.  See L</DEPARTURE TYPES>.

=back

=head2 INTERNAL

=over

=item $departure = Travel::Status::DE::GTFS::Result->new(I<%data>)

Returns a new Travel::Status::DE::GTFS::Result object.  You should not need to
call this.

=item $departure->TO_JSON

Allows the object data to be serialized to JSON.
lt 
=back

=head1 DEPARTURE TYPES

The following are known so far:

=over

=item * Abellio-Zug

=item * Bus

=item * Eurocity

=item * Intercity-Express

=item * NE (NachtExpress / night bus)

=item * Niederflurbus

=item * R-Bahn (RE / RegionalExpress)

=item * S-Bahn

=item * SB (Schnellbus)

=item * StraE<szlig>enbahn

=item * U-Bahn

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

none so far

=head1 SEE ALSO

Travel::Status::DE::GTFS(3pm).

=head1 ACKNOWLEDGEMENTS

This is heavily based on Travel::Status::DE::EFA and Travel::Status::DE::EFA::Result, both by Daniel Friesel C<< <derf@finalrewind.org> >>

=head1 AUTHOR

Stefan T. Kaufmann, C<< <stefan.t.kaufmann at googlemail.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Stefan T. Kaufmann.

This module is licensed under the same terms as Perl itself.

=cut
1;
