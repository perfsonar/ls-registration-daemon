package perfSONAR_PS::LSRegistrationDaemon::Base;

use strict;
use warnings;

use Socket;
use Socket6;
use Log::Log4perl qw/get_logger/;

use perfSONAR_PS::Utils::DNS qw(reverse_dns);
use perfSONAR_PS::Client::LS::Remote;

use fields 'CONF', 'STATUS', 'LOGGER', 'KEY', 'NEXT_REFRESH', 'LS_CLIENT';

sub new {
    my $class = shift;

    my $self = fields::new( $class );

    $self->{LOGGER} = get_logger( $class );

    return $self;
}

sub init {
    my ( $self, $conf ) = @_;

    $self->{CONF}   = $conf;
    $self->{STATUS} = "UNREGISTERED";

    if ( $conf->{ls_instance} ) {
        $self->{LS_CLIENT} = perfSONAR_PS::Client::LS->new({ instance => $conf->{ls_instance} });
    }
    else {
        $self->{LS_CLIENT} = perfSONAR_PS::Client::LS->new();
    }

    return 0;
}

sub service_name {
    my ( $self ) = @_;

    if ( $self->{CONF}->{service_name} ) {
        return $self->{CONF}->{service_name};
    }

    my $retval = q{};
    if ( $self->{CONF}->{site_name} ) {
        $retval .= $self->{CONF}->{site_name} . " ";
    }
    $retval .= $self->type();

    return $retval;
}

sub service_desc {
    my ( $self ) = @_;

    if ( $self->{CONF}->{service_name} ) {
        return $self->{CONF}->{service_name};
    }

    my $retval = $self->type();
    if ( $self->{CONF}->{site_name} ) {
        $retval .= " at " . $self->{CONF}->{site_name};
    }

    if ( $self->{CONF}->{site_location} ) {
        $retval .= " in " . $self->{CONF}->{site_location};
    }

    return $retval;
}

sub refresh {
    my ( $self ) = @_;

    if ( $self->{STATUS} eq "BROKEN" ) {
        $self->{LOGGER}->debug( "Refreshing broken service" );
        return;
    }

    $self->{LOGGER}->debug( "Refreshing: " . $self->service_desc );

    if ( $self->is_up ) {
        $self->{LOGGER}->debug( "Service is up" );
        if ( $self->{STATUS} ne "REGISTERED" ) {
            $self->register();
        }
        elsif ( time >= $self->{NEXT_REFRESH} ) {
            $self->keepalive();
        }
        else {
            $self->{LOGGER}->debug( "No need to refresh" );
        }
    }
    elsif ( $self->{STATUS} eq "REGISTERED" ) {
        $self->{LOGGER}->debug( "Service isn't" );
        $self->unregister();
    }
    else {
        $self->{LOGGER}->debug( "Service failed" );
    }

    return;
}

sub register {
    my ( $self ) = @_;

    my $addresses = $self->get_service_addresses();

    my @metadata = ();
    my %service  = ();
    $service{nonPerfSONARService} = 1;
    $service{name}                = $self->service_name();
    $service{description}         = $self->service_desc();
    $service{type}                = $self->service_type();
    $service{addresses}           = $addresses;

    my $ev       = $self->event_type();
    my $projects = $self->{CONF}->{site_project};

    my $node_addresses = $self->get_node_addresses();

    my $md = q{};
    $md .= "<nmwg:metadata id=\"" . int( rand( 9000000 ) ) . "\">\n";
    $md .= "  <nmwg:subject>\n";
    $md .= $self->create_node( $node_addresses );
    $md .= "  </nmwg:subject>\n";
    $md .= "  <nmwg:eventType>$ev</nmwg:eventType>\n";
    if ( $projects ) {
        $md .= "  <nmwg:parameters>\n";
        if ( ref( $projects ) eq "ARRAY" ) {
            foreach my $project ( @$projects ) {
                $md .= "    <nmwg:parameter name=\"keyword\">project:" . $project . "</nmwg:parameter>\n";
            }
        }
        else {
            $md .= "    <nmwg:parameter name=\"keyword\">project:" . $projects . "</nmwg:parameter>\n";
        }
        $md .= "  </nmwg:parameters>\n";
    }
    $md .= "</nmwg:metadata>\n";

    push @metadata, $md;

    my $res = $self->{LS_CLIENT}->registerRequestLS( service => \%service, data => \@metadata );
    if ( $res and $res->{"key"} ) {
        $self->{LOGGER}->debug( "Registration succeeded with key: " . $res->{"key"} );
        $self->{STATUS}       = "REGISTERED";
        $self->{KEY}          = $res->{"key"};
        $self->{NEXT_REFRESH} = time + $self->{CONF}->{"ls_interval"};
    }
    else {
        my $error;
        if ( $res and $res->{error} ) {
            $self->{LOGGER}->debug( "Registration failed: " . $res->{error} );
        }
        else {
            $self->{LOGGER}->debug( "Registration failed" );
        }
    }

    return;
}

sub keepalive {
    my ( $self ) = @_;

    my $res = $self->{LS_CLIENT}->keepaliveRequestLS( key => $self->{KEY} );
    if ( $res->{eventType} ne "success.ls.keepalive" ) {
        $self->{STATUS} = "UNREGISTERED";
        $self->{LOGGER}->debug( "Keepalive failed" );
    }

    return;
}

sub unregister {
    my ( $self ) = @_;

    $self->{LS_CLIENT}->deregisterRequestLS( key => $self->{KEY} );
    $self->{STATUS} = "UNREGISTERED";

    return;
}

sub create_node {
    my ( $self, $addresses ) = @_;
    my $node = q{};

    my $nmtb  = "http://ogf.org/schema/network/topology/base/20070828/";
    my $nmtl3 = "http://ogf.org/schema/network/topology/l3/20070828/";

    $node .= "<nmtb:node xmlns:nmtb=\"$nmtb\" xmlns:nmtl3=\"$nmtl3\">\n";
    foreach my $addr ( @$addresses ) {
        my $name = reverse_dns( $addr->{value} );
        if ( $name ) {
            $node .= " <nmtb:name type=\"dns\">$name</nmtb:name>\n";
        }
    }

    foreach my $addr ( @$addresses ) {
        $node .= " <nmtl3:port>\n";
        $node .= "   <nmtl3:address type=\"" . $addr->{type} . "\">" . $addr->{value} . "</nmtl3:address>\n";
        $node .= " </nmtl3:port>\n";
    }
    $node .= "</nmtb:node>\n";

    return $node;
}

1;
