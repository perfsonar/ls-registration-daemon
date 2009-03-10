package perfSONAR_PS::LSRegistrationDaemon::OWAMP;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::TCP_Service';

use constant DEFAULT_PORT => 861;

sub init {
    my ( $self, $conf ) = @_;

    my $res;
    if ( $conf->{config_file} ) {
        my $owamp_config = $conf->{config_file};

        $res = read_owamp_config( $owamp_config );
        if ( $res->{error} ) {
            $self->{LOGGER}->error( "Problem reading owamp configuation: " . $res->{error} );
            $self->{STATUS} = "BROKEN";
            return -1;
        }
    }
    else {
        my %tmp = ();
        $res = \%tmp;
    }

    if ( not $conf->{port} and not $res->{port} ) {
        $conf->{port} = DEFAULT_PORT;
    }
    elsif ( not $conf->{port} ) {
        $conf->{port} = $res->{port};
    }

    if ( $res->{addr} ) {
        my @tmp_addrs = ();
        push @tmp_addrs, $res->{addr};

        $conf->{address} = \@tmp_addrs;
    }

    return $self->SUPER::init( $conf );
}

sub read_owamp_config {
    my ( $file ) = @_;

    my %conf = ();

    my $FH;

    open( $FH, "<", $file ) or return \%conf;
    while ( my $line = <$FH> ) {
        $line =~ s/#.*//;     # get rid of any comment on the line
        $line =~ s/^\S+//;    # get rid of any leading whitespace
        $line =~ s/\S+$//;    # get rid of any trailing whitespace

        my ( $key, $value ) = split( /\S+/, $line );
        if ( not $key ) {
            next;
        }

        if ( $value ) {
            $conf{$key} = $value;
        }
        else {
            $conf{$key} = 1;
        }
    }
    close( $FH );

    my $addr_to_parse;

    if ( $conf{"srcnode"} ) {
        $addr_to_parse = $conf{"srcnode"};
    }
    elsif ( $conf{"src_node"} ) {
        $addr_to_parse = $conf{"src_node"};
    }

    my ( $addr, $port );

    if ( $addr_to_parse and $addr_to_parse =~ /(.*):(.*)/ ) {
        $addr = $1;
        $port = $2;
    }

    my %res = ();
    if ( $addr ) {
        $res{addr} = $addr;
    }
    $res{port} = $port;

    return \%res;
}

sub type {
    my ( $self ) = @_;

    return "OWAMP Server";
}

sub service_type {
    my ( $self ) = @_;

    return "owamp";
}

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/owamp/1.0";
}

1;
