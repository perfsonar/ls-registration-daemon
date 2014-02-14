package perfSONAR_PS::LSRegistrationDaemon::BWCTL;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::BWCTL - The BWCTL class provides checks for
BWCTL services.

=head1 DESCRIPTION

This module provides the request functions to check a service, and the
information necessary for the Base module to construct a bwctl service
instance.

=cut

use strict;
use warnings;

our $VERSION = 3.3;

use base 'perfSONAR_PS::LSRegistrationDaemon::TCP_Service';

use fields 'TOOLS';

use constant DEFAULT_PORT => 4823;

my @known_tools = (
    { id=>0x01, name => "iperf" },
    { id=>0x02, name => "nuttcp" },
    { id=>0x04, name => "thrulay" },
    { id=>0x08, name => "iperf3" },
    { id=>0x10, name => "ping" },
    { id=>0x20, name => "traceroute" },
    { id=>0x40, name => "tracepath" },
    { id=>0x80, name => "owamp" },
);

=head2 init($self, $conf)

This function reads the bwctl configuration file (if appropriate), and then
passes the appropriate address and port to the TCP service init routines.

=cut

sub init {
    my ( $self, $conf ) = @_;

    my $res;
    if ( $conf->{config_file} ) {
        my $bwctl_config = $conf->{config_file};

        $res = read_bwctl_config( $bwctl_config );
        if ( $res->{error} ) {
            $self->{LOGGER}->error( "Problem reading bwctl configuation: " . $res->{error} );
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

=head2 read_bwctl_config($file)

This function reads the bwctl configuration file and returns the address and
port that the service listens on if set.

=cut

sub read_bwctl_config {
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

=head2 type($self)

Returns the human readable description of the service "BWCTL Server".

=cut

sub type {
    my ( $self ) = @_;

    return "BWCTL Server";
}

=head2 type($self)

Returns the bwctl service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "bwctl";
}

=head2 type($self)

Returns the bwctl event type.

=cut

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/bwctl/1.0";
}

sub build_registration {
    my ( $self ) = @_;

    my $service = $self->SUPER::build_registration();

    $service->setBWCTLTools($self->{TOOLS}) if $self->{TOOLS};

    return $service;
}

sub connected_cb {
    my ( $self, $sock ) = @_;

    my $res = __bwctl_read_server_greeting($sock);

    if ($res and $res->{protocol}) {
        __bwctl_write_client_greeting($sock, $res->{protocol});

        $res = __bwctl_read_server_ok($sock);

        my $tool_mask = $res->{tools};

        my @avail_tools = ();
        foreach my $tool (@known_tools) {
            if ($tool_mask & $tool->{id}) {
                push @avail_tools, $tool->{name};
            }
        }

        $self->{TOOLS} = \@avail_tools;
    }

    return 1;   
}

sub __bwctl_read_server_greeting {
    my ($sock) = @_;

    my $data;

    unless (defined $sock->recv($data, 32)) {
        return;
    }

    my ($unused, $protocol_modes, $challenge) = unpack("a12 N a16", $data);

    my $protocol = $protocol_modes >> 24;
    my $mode = $protocol_modes << 8 >> 8;

    return { protocol => $protocol, mode => $mode, challenge => $challenge };
}

sub __bwctl_write_client_greeting {
    my ($sock, $protocol) = @_;

    # 1 is "open"
    my $protocol_mode = 1 | ($protocol << 24);

    my $data = pack("N x64", $protocol_mode);

    unless (defined $sock->send($data, 68)) {
        return;
    }
}

sub __bwctl_read_server_ok {
    my ($sock) = @_;

    my $data;

    unless (defined $sock->recv($data, 48)) {
        return;
    }

    my ($tools, $unused, $accept, $server_iv, $uptime, $iv) = unpack("N a11 C a16 a8 a8", $data);

    #$tools = unpack('B32', $tools);

    return { tools => $tools, accept => $accept, server_iv => $server_iv, uptime => $uptime, iv => $iv };
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::LSRegistrationDaemon::TCP_Service>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 COPYRIGHT

Copyright (c) 2007-2010, Internet2

All rights reserved.

=cut
