package Travel::Status::DE::GTFS;

use 5.010;
use strict;
use warnings FATAL => 'all';

use experimental 'smartmatch';

use Carp qw(confess cluck);
use DateTime;
use DateTime::Duration;
use Encode qw(encode decode);
use Travel::Status::DE::GTFS::Result;
use DBI;

our $LocalTZ = DateTime::TimeZone->new( name => 'local' );


sub new {
	my ( $class, %opt ) = @_;

	my $date = DateTime->now(time_zone => $LocalTZ);

	if ( not( $opt{place} ) ) {
		confess('You need to specify a place (stop)');
	}
	if ( $opt{type} and not( $opt{type} ~~ [qw[name id code]] ) ) {
		confess('place type must be name (stop_name), id (stop_id) or code (stop_code)');
	}

	if ( not $opt{gtfs_db} ) {
		confess('gtfs_db is mandatory');
	}

	if (    $opt{time}
		and $opt{time} =~ m{ ^ (?<hour> \d\d? ) : (?<minute> \d\d ) $ }x )
	{
		$date->set_hour($+{hour});
		$date->set_minute($+{minute});
	}
	elsif ( $opt{time} ) {
		confess('Invalid time specified');
	}


	if (
		    $opt{date}
		and $opt{date} =~ m{ ^ (?<year> \d{4} )? [-] (?<month> \d\d? ) [-]
			(?<day> \d\d? )? $ }x
	  )
	{
		if ( $+{year} ) {
			$date->set_year($+{year});
			$date->set_month($+{month});
			$date->set_day($+{day});
		}
		else {
			$date->set_month($+{month});
			$date->set_day($+{day});
		}
	}
	elsif ( $opt{date} ) {
		confess('Invalid date specified, please use ISO format YYYY-MM-DD or MM-DD');
	}
	
	my $dsn = "DBI:SQLite:dbname=" . $opt{gtfs_db};
	my $userid = "";
	my $password = "";
	my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) 
		or confess( $DBI::errstr );


	my $timestring = $date->strftime("%T");
	my $today_datestring = $date->strftime("%Y%m%d");
	my $tomorrow_date = $date->clone();
	$tomorrow_date->add (days => 1);
	my $tomorrow_datestring = $tomorrow_date->strftime("%Y%m%d");

	my $today_dayofweek;
	my $tomorrow_dayofweek;
	
	if ($date->day_of_week() == "1") { 
			$today_dayofweek    = 'monday'; 
			$tomorrow_dayofweek = 'tuesday'; 
			}
	elsif ($date->day_of_week() == "2") { 
			$today_dayofweek    = 'tuesday'; 
			$tomorrow_dayofweek = 'wednesday';
			}
	elsif ($date->day_of_week() == "3") { 
			$today_dayofweek    = 'wednesday'; 
			$tomorrow_dayofweek = 'thursday';
			}
	elsif ($date->day_of_week() == "4") { 
			$today_dayofweek    = 'thursday';
			$tomorrow_dayofweek = 'friday';
			}
	elsif ($date->day_of_week() == "5") { 
			$today_dayofweek    = 'friday';
			$tomorrow_dayofweek = 'saturday';
			}
	elsif ($date->day_of_week() == "6") { 
			$today_dayofweek    = 'saturday';
			$tomorrow_dayofweek = 'sunday';
			}
	else { 
			$today_dayofweek    = 'sunday';
			$tomorrow_dayofweek = 'monday';
			}



	my $sqlstatement = 'SELECT DISTINCT route.route_short_name, route.route_long_name, trip.trip_headsign, times.stop_headsign, route.route_color, route.route_text_color, times.departure_time, trip.trip_id, stop.stop_id, stop.stop_name, ? AS caldate
FROM stop_times times
JOIN trips trip ON trip.trip_id = times.trip_id
JOIN routes route ON route.route_id = trip.route_id
JOIN calendar calendar ON calendar.service_id = trip.service_id
JOIN calendar_dates dates ON dates.service_id = calendar.service_id ';

	if ( $opt{type} and $opt{type} eq "id") {
		$sqlstatement = $sqlstatement . 'INNER JOIN stops stop ON stop.stop_id = ?';
	} elsif ( $opt{type} and $opt{type} eq "code") {
		$sqlstatement = $sqlstatement . 'INNER JOIN stops stop ON stop.stop_code = ?';
	} else {
		$sqlstatement = $sqlstatement . 'INNER JOIN stops stop ON stop.stop_name = ?';
	}

	$sqlstatement = $sqlstatement . '
	WHERE times.stop_id = stop.stop_id AND times.departure_time >= ? AND ( calendar.' . $today_dayofweek . ' = "1" 
	AND calendar.start_date <= ? AND calendar.end_date >= ? AND trip.service_id NOT IN (SELECT service_id from calendar_dates where date = ? AND exception_type = "2") OR ( dates.date = ? AND dates.exception_type = 1 ))
	AND (SELECT count(time.stop_id) FROM stop_times time WHERE time.trip_id = trip.trip_id AND time.arrival_time > times.departure_time) > 0

	UNION ALL

	SELECT DISTINCT route.route_short_name, route.route_long_name, trip.trip_headsign, times.stop_headsign, route.route_color, route.route_text_color, times.departure_time, trip.trip_id, stop.stop_id, stop.stop_name, ? as caldate
FROM stop_times times
JOIN trips trip ON trip.trip_id = times.trip_id
JOIN routes route ON route.route_id = trip.route_id
JOIN calendar calendar ON calendar.service_id = trip.service_id
JOIN calendar_dates dates ON dates.service_id = calendar.service_id ';

	if ( $opt{type} and $opt{type} eq "id") {
		$sqlstatement = $sqlstatement . 'INNER JOIN stops stop ON stop.stop_id = ?';
	} elsif ( $opt{type} and $opt{type} eq "code") {
		$sqlstatement = $sqlstatement . 'INNER JOIN stops stop ON stop.stop_code = ?';
	} else {
		$sqlstatement = $sqlstatement . 'INNER JOIN stops stop ON stop.stop_name = ?';
	}

	$sqlstatement = $sqlstatement . '
	WHERE times.stop_id = stop.stop_id AND times.departure_time < ? AND ( calendar.' . $tomorrow_dayofweek . ' = "1" AND calendar.start_date <= ? AND calendar.end_date >= ? AND trip.service_id NOT IN (SELECT service_id from calendar_dates where date = ? AND exception_type = "2") OR ( dates.date = ? AND dates.exception_type = 1 ))
AND (SELECT count(time.stop_id) FROM stop_times time WHERE time.trip_id = trip.trip_id AND time.arrival_time > times.departure_time) > 0
	
	ORDER BY caldate, times.departure_time';

#	print("$sqlstatement\n" . $opt{place} . " $timestring $today_datestring $tomorrow_datestring\n");

	my $sth = $dbh->prepare($sqlstatement);
	$sth->execute($today_datestring,$opt{place},$timestring ,$today_datestring, $today_datestring, $today_datestring, $today_datestring,$tomorrow_datestring,$opt{place},$timestring ,$tomorrow_datestring, $tomorrow_datestring, $tomorrow_datestring, $tomorrow_datestring);

	# TODO build errstr if 0 results

	my $self;

	$self->{array} = $sth->fetchall_arrayref;

	bless( $self, $class );

	return $self;
}

sub results {
	my ($self, %opt) = @_;
	my @results;
	
	my $currentDate = DateTime->now(time_zone => $LocalTZ);

#	if ( $self->{results} ) {
#		return @{ $self->{results} };
#	}


	foreach my $row ( @{$self->{array}} ) {
		my @currentrow = @{$row};
		
		$currentrow[10] =~ m{ (?<year> \d{4} )(?<month> \d\d )(?<day> \d\d ) }x;
		
		my $resultDate = DateTime->new( 
			year => $+{year},
			month => $+{month},
			day => $+{day},
			hour => 0,
			minute => 0,
			second => 0);
			
		my $scheduled_date = $+{day} . "." . $+{month}  . "." . $+{year};
		
		$currentrow[6] =~ m{ (?<hours> \d{2}) [:] (?<minutes>\d{2}) ([:] (?<seconds>\d{2})) }x;
		my $timeOffset = DateTime::Duration->new( 
			hours   => $+{hours},
			minutes => $+{minutes},
		);
		
		my $scheduled_time = $+{hours} . ":" . $+{minutes} . ":" . $+{seconds};
		
		if (defined $+{seconds}) {
			$timeOffset->add( 
				seconds => $+{seconds}
				);
		}
		$resultDate->add_duration($timeOffset);
		my $remainingTime = $currentDate->delta_ms( $resultDate );
		my $countdown = $remainingTime->in_units( 'minutes');
		if (DateTime->compare($resultDate, $currentDate) < 0) {
			$countdown *= -1;
		}
		
		my $headsign;
		if (defined $currentrow[2]) {
			$headsign = $currentrow[2];
		}
		if (defined $currentrow[3] and $currentrow[3] ne "") {
			$headsign = $currentrow[3];
		}
		
		
		my $line_name;
		if (defined $currentrow[1]) {
			$line_name = $currentrow[1];
		}
		if (defined $currentrow[0] and $currentrow[0] ne "") {
			$line_name = $currentrow[0];
		}
		
		if ((DateTime->compare($resultDate, $currentDate) >= 0) or not defined $opt{purge}) {
			push(
				@results,
				Travel::Status::DE::GTFS::Result->new(
					time          => $resultDate->strftime("%T"),
					date          => $resultDate->strftime("%d.%m.%Y"),
					sched_date    => $scheduled_date,
					sched_time    => $scheduled_time,
					platform      => $currentrow[8],
					platform_name => $currentrow[9],
					key           => $currentrow[7],
					line          => $line_name,
					destination   => decode('utf-8', $headsign),
					countdown     => $countdown,
#					info          => decode( 'UTF-8', $info ),
#					type          => $type,
				)
			);
		}
	}

	$self->{results} = \@results;

	return @results;
}



sub errstr {
	my ($self) = @_;

	return $self->{errstr};
}


=head1 NAME

Travel::Status::DE::GTFS - Getting Departure Times from a GTFS Feed

=head1 VERSION

Version 0.04

=cut

our $VERSION = '0.04';


=head1 SYNOPSIS

    use Travel::Status::DE::GTFS;

    my $status = Travel::Status::DE::GTFS->new(
        feed_db => 'gtfs.db',
        place => 'Ulm Hauptbahnhof'
    );

    for my $d ($status->results) {
        printf(
            "%s %-8s %-5s %s\n",
            $d->time, $d->platform_name, $d->line, $d->destination
        );
    }

=head1 EXPORT


=head1 METHODS

=over

=item my $status = Travel::Status::DE::GTFS->new(I<%opt>)

Requests the departures as specified by I<opts> and returns a new
Travel::Status::DE::GTFS object.  Dies if the wrong I<opts> were passed.

Arguments:

=over

=item B<gtfs_db> => I<database file>

file name of SQLite database containing the GTFS feed to be used.  Make sure you built your GTFS feed database properly, with good indices to make SQL requests as fast as possible. A well designed database will yield the desired results within a few seconds even on a Raspberry Pi, a poorly built one will tage ages.

=item B<place> => I<place>

Stop to list departures for.

=back

=item $status->errstr

In case of an ambiguous place/stop name combination or any other 
error, returns a string describing it. If none occured, returns undef.

=item $status->lines

Returns a list of Travel::Status::DE::GTFS::Line(3pm) objects, each one
describing one line servicing the selected station.

=item $status->results

Returns a list of Travel::Status::DE::GTFS::Result(3pm) objects, each one describing
one departure.

=back


=head1 DEPENDENCIES

libdatetime-perl libclass-accessor-perl libclass-dbi-sqlite-perl

=head1 ISSUES

As of now, this module ignores the timezone settings within GTFS feeds, as the reference/test cases have proven this can be a pain in the butt.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Travel::Status::DE::GTFS


=head1 ACKNOWLEDGEMENTS

This is heavily based on Travel::Status::DE::EFA and Travel::Status::DE::EFA::Result, both by Daniel Friesel C<< <derf@finalrewind.org> >>

=head1 AUTHOR

Stefan T. Kaufmann, C<< <stefan.t.kaufmann at googlemail.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Stefan T. Kaufmann.

This module is licensed under the same terms as Perl itself.

=cut

1; # End of Travel::Status::DE::GTFS
