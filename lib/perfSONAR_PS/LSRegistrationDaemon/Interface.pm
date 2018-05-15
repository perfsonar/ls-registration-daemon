package perfSONAR_PS::LSRegistrationDaemon::Interface;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';
use Data::Validate::IP qw(is_ipv6);
use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Client::LS::PSRecords::PSInterface;

use perfSONAR_PS::Utils::Host qw(discover_primary_address);

sub known_variables {
    my ($self) = @_;

    my @variables = $self->SUPER::known_variables();

    push @variables, (
        { variable => "address", type => "array" },

        { variable => "autodiscover", type => "scalar" },
        { variable => "capacity", type => "scalar" },
        { variable => "domain", type => "array" },
        { variable => "if_name", type => "scalar" },
        { variable => "if_type", type => "scalar" },
        { variable => "is_local", type => "scalar" },
        { variable => "mac_address", type => "scalar" },
        { variable => "mtu", type => "scalar" },
        { variable => "subnet", type => "scalar" },
        { variable => "urn", type => "scalar" },
        { variable => "disable_autodiscover_tests", type => "scalar" },
        { variable => "test", type => "array" },
        { variable => "disable_test", type => "array" },
    );

    return @variables;
}

=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;

    if ($conf->{autodiscover} and not $conf->{is_local}) {
        die "Non-local host defined as 'autodiscover'";
    }

    if ($conf->{autodiscover} and not $conf->{if_name}) {
        die "No interface name specified for 'autodiscover' interface";
    }

    $conf->{address} = [] unless $conf->{address};
    $conf->{address} = [ $conf->{address} ] unless ref($conf->{address}) eq "ARRAY";

    if ($conf->{autodiscover}) {
        my $addresses = discover_primary_address(
                            interface => $conf->{if_name},
                            allow_rfc1918 => $conf->{allow_internal_addresses},
                            disable_ipv4_reverse_lookup => $conf->{disable_ipv4_reverse_lookup},
                            disable_ipv6_reverse_lookup => $conf->{disable_ipv6_reverse_lookup},
                        );

        push @{ $conf->{address} }, $addresses->{primary_address} if $addresses->{primary_address};
        push @{ $conf->{address} }, $addresses->{primary_ipv4} if $addresses->{primary_ipv4};
        push @{ $conf->{address} }, $addresses->{primary_ipv6} if $addresses->{primary_ipv6};
        $conf->{capacity} = $addresses->{primary_iface_speed} if($addresses->{primary_iface_speed});
        $conf->{mtu} = $addresses->{primary_iface_mtu} if($addresses->{primary_iface_mtu});
        $conf->{mac_address} = $addresses->{primary_iface_mac} if($addresses->{primary_iface_mac});
        #Autodiscover tools and test types
        unless($conf->{'disable_autodiscover_tests'}){
            #get disabled tests
            my $disabled_test = {};
            $conf->{disable_test} = [] unless $conf->{disable_test};
            $conf->{disable_test} = [ $conf->{disable_test} ] unless ref($conf->{disable_test}) eq "ARRAY";
            foreach my $dt(@{$conf->{disable_test}}){
                $disabled_test->{$dt} = 1;
            }
            
            my @auto_urls = ();
            if($conf->{'autodiscover_tests_url'}){
                push @auto_urls, $conf->{'autodiscover_tests_url'};
            }else{
                foreach my $addr(@{$conf->{address}}){
                    if(is_ipv6($addr)){
                        push @auto_urls, "https://[$addr]/pscheduler";
                    }else{
                        push @auto_urls, "https://$addr/pscheduler";
                    }
                }
            }
            my $filters = new perfSONAR_PS::Client::PScheduler::ApiFilters(
                    ca_certificate_file => $conf->{'autodiscover_ca_file'},
                    ca_certificate_path => $conf->{'autodiscover_ca_path'},
                    verify_hostname => $conf->{'autodiscover_verify_hostname'},
                );
            foreach my $auto_url(@auto_urls){
                my $client = new perfSONAR_PS::Client::PScheduler::ApiConnect("url" => $auto_url, "filters" => $filters);
                my $tests =  $client->get_tests();
                if($client->error()){
                    $self->{LOGGER}->warn("Unable to get pScheduler test types from $auto_url: " . $client->error);
                }else{
                    $conf->{test} = [];
                    foreach my $test(@{$tests}){
                        push @{$conf->{test}}, $test->name() unless($disabled_test->{$test->name()});
                    }
                    last;
                }
            }
        }
        
        #remove any duplicates
        my %test_map = ();
        $conf->{test} = [] unless $conf->{test};
        $conf->{test} = [ $conf->{test} ] unless ref($conf->{test}) eq "ARRAY";
        foreach my $t(@{$conf->{test}}){
            $test_map{$t} = 1;
        }
        my @tmp_test = keys %test_map;
        $conf->{test} = \@tmp_test;
    }

    # Make sure that addresses are unique
    my %addresses = ();
    foreach my $address (@{ $conf->{address} }) {
        $addresses{$address} = 1;
    }
    my @addresses = keys %addresses;

    $conf->{address} = \@addresses;

    unless (scalar(@{ $conf->{address} }) > 0) {
        die("No address for interface ".$conf->{if_name});
    }

    return $self->SUPER::init( $conf );
}

sub is_up {
    #die "Subclass must implement is_up"; 
    return 1;
}

=head2 service_name ($self)

This internal function generates the name to register this service as. It calls
the object-specific function "type" when creating the function.

=cut

sub autodiscover {
    my ($self) = @_;

    return $self->{CONF}->{autodiscover};
}

sub is_local {
    my ($self) = @_;

    return $self->{CONF}->{is_local};
}

sub description {
    my ( $self ) = @_;

    return $self->if_name() . '';
}
            
sub if_name {
    my ( $self ) = @_;

    return $self->{CONF}->{if_name};
}

sub address {
    my ( $self ) = @_;

    return $self->{CONF}->{address};
}

sub mac_address {
    my ( $self ) = @_;

    return $self->{CONF}->{mac_address};
}

sub mtu {
    my ( $self ) = @_;

    return $self->{CONF}->{mtu} . ""; #cast to string or registration fails
}

sub subnet {
    my ( $self ) = @_;

    return $self->{CONF}->{subnet};
}

sub capacity {
    my ( $self ) = @_;

    return $self->{CONF}->{capacity} . ""; #cast to string or registration fails
}

sub if_type {
    my ( $self ) = @_;

    return $self->{CONF}->{if_type};
}

sub urn {
    my ( $self ) = @_;

    return $self->{CONF}->{urn};
}

sub domain {
    my ( $self ) = @_;

    return $self->{CONF}->{domain};
}

sub test {
    my ( $self ) = @_;

    return $self->{CONF}->{test};
}

#not a field, just a utility function
sub has_ipv6 {
    my ( $self ) = @_;
    
    foreach my $address (@{ $self->{CONF}->{address} }) {
        if(is_ipv6($address)){
            return 1;
        }
    }
    
    return 0;
}

sub build_registration {
    my ( $self ) = @_;
    
    my $iface = new perfSONAR_PS::Client::LS::PSRecords::PSInterface();
    $iface->init(
        interfaceName => $self->if_name(), 
        interfaceAddresses => $self->address(), 
        subnet => $self->subnet(), 
        macAddress=> $self->mac_address(), 
        domains=> $self->domain(),
    );
    $iface->setPSchedulerTests($self->test()) if($self->test());
    $iface->setInterfaceCapacity($self->capacity()) if($self->capacity());
    $iface->setInterfaceMTU($self->mtu()) if(defined $self->mtu());
    $iface->setInterfaceType($self->if_type()) if(defined $self->if_type());
    $iface->setUrns($self->urn()) if(defined $self->urn());
    
    return $iface;
}


sub checksum_prefix {
    return "interface";
}

sub checksum_fields {
    return [
        "if_name",
        "address",
        "subnet",
        "capacity",
        "mac_address",
        "domain",
        "mtu",
        "if_type",
        "urn",
    ];
}

sub duplicate_checksum_fields {
    return [
        "if_name",
        "address",
    ];
}

1;
