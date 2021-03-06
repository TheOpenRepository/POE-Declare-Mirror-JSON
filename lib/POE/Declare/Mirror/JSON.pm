package POE::Declare::Mirror::JSON;

=pod

=head1 NAME

POE::Declare::Mirror::JSON - Mirror configuration and auto-discovery

=head1 SYNOPSIS

    my $client = POE::Declare::Mirror::JSON->new(
        Timeout     => 10,
        MirrorEvent => \&selected_mirror,
    );
    
    $client->;

=head1 DESCRIPTION

This is a port of L<LWP::Online> to L<POE::Declare>. It behaves similarly to
the original, except that it does not depend on LWP and can execute the HTTP
probes in parallel.

=cut

use 5.008;
use strict;
use URI                        1.54 ();
use File::Spec                 0.80 ();
use Time::HiRes              1.9721 ();
use Time::Local              1.1901 ();
use Params::Util               1.00 ();
use POE::Declare::HTTP::Client 0.04 ();

our $VERSION = '0.01';

use POE::Declare 0.54 {
	Timeout        => 'Param',
	Parallel       => 'Param',
	SelectionEvent => 'Message',
	ErrorEvent     => 'Message',
	client         => 'Internal',
	elapsed        => 'Internal',
};





######################################################################
# Constructor and Accessors

sub new {
	my $self = shift->SUPER::new(@_);

	# Check params
	unless ( Params::Util::_POSINT($self->Parallel) ) {
		$self->{Parallel} = 5;
	}

	return $self;
}

sub clients {
	@{ $_[0]->{client} };
}





######################################################################
# Main Methods

sub run {
	my $self = shift;
	unless ( @_ ) {
		return undef;
	}

	$self->{mirror} = {
		map {
			$_ => {
				age      => undef,
				speed    => undef,
				tstart   => undef,
				tstop    => undef,
				response => undef,
			}
		} @_
	};

	$self->{queue} = [
		sort { rand() <=> rand() }
		keys %{ $self->{mirror} }
	];

	return 1;
}





######################################################################
# Event Handlers

sub _start :Event {
	$_[SELF]->SUPER::_start(@_[1..$#_]);

	# Initialise the clients
	my $client  = $_[SELF]->{client}  = { };
	my $elapsed = $_[SELF]->{elapsed} = { };
	foreach ( 1 .. $_[SELF]->Parallel ) {
		my $http = POE::Declare::HTTP::Client->new(
			Timeout        => 5,
			ResponseEvent  => $_[SELF]->lookback('http_response'),
			ShutdownEvenet => $_[SELF]->lookback('http_shutdown'),
		);
		$client->{$http->Alias} = $http;
		$client->{$http->Alias}->start;
	}

	# Yield so that the actual requests don't accidentally start before
	# the kernel is running (_start can fire fairly early)
	$_[SELF]->post('startup');
}

sub startup :Event {
	# Do the initial fill from the queue
	foreach my $client ( $_[SELF]->clients ) {
		my $uri = shift @{ $_[SELF]->{queue} } or last;
		$_[SELF]->request($client, $uri);
	}
}

sub http_response :Event {
	my $queue    = $_[SELF]->{queue};
	my $alias    = $_[ARG0];
	my $response = $_[ARG1];

	
}

sub http_shutdown :Event {
	
}





######################################################################
# Support Methods

sub request {
	my $self   = shift;
	my $client = shift;
	my $uri    = shift;
	my $mirror = $self->{mirror}->{$uri} or return;
	$mirror->{tstart} = Time::HiRes::time();
	$client->GET($uri);
	return 1;
}

compile;

=pod

=head1 SUPPORT

Bugs should be always be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Declare-Mirror-JSON>

For other issues, or commercial enhancement or support, contact the author.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 SEE ALSO

L<LWP::Simple>

=head1 COPYRIGHT

Copyright 2011 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
