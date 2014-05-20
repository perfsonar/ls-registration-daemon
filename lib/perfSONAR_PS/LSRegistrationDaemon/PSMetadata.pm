package perfSONAR_PS::LSRegistrationDaemon::PSMetadata;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';
use Digest::MD5 qw(md5_base64);
use SimpleLookupService::Records::Record;
use perfSONAR_PS::Common qw(mergeConfig);

use fields 'METADATA_HASH';
use constant RESERVED_LS_KEYS => {
    'uri' => 1,
};
=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;
    
    #NOTE: If in future support other subject types, change the requirement for source and dest
    if(!$conf->{source}){
        $self->{LOGGER}->error("Must specify source for test");
        return -1;
    }
    if(!$conf->{destination}){
        $self->{LOGGER}->error("Must specify destination for test");
        return -1;
    }
    if(!$conf->{event_type}){
        $self->{LOGGER}->error("Must specify event_type for test");
        return -1;
    }
    if(!$conf->{result_index} ||  ref($conf->{result_index}) ne 'ARRAY'){
        $conf->{result_index} = [];
    }
    
    return $self->SUPER::init( $conf );
}

sub is_up {
    return 1;
}

sub ma_locator {
    my ( $self ) = @_;

    return $self->{CONF}->{ma_locator};
}

sub metadata_uri {
    my ( $self ) = @_;

    return $self->{CONF}->{metadata_uri};
}

sub description {
    my ( $self ) = @_;

    return "metadata " . $self->source() . ' to ' . $self->destination();
}

sub source {
    my ( $self ) = @_;

    return $self->{CONF}->{source};
}

sub destination {
    my ( $self ) = @_;

    return $self->{CONF}->{destination};
}

sub measurement_agent {
    my ( $self ) = @_;

    return $self->{CONF}->{measurement_agent};
}

sub tool_name {
    my ( $self ) = @_;

    return $self->{CONF}->{tool_name};
}

sub event_type {
    my ( $self ) = @_;

    return $self->{CONF}->{event_type};
}

sub communities {
    my ( $self ) = @_;

    return $self->{CONF}->{site_project};
}

sub domain {
    my ( $self ) = @_;

    return $self->{CONF}->{domain};
}

sub result_index {
    my ( $self ) = @_;
    
    return $self->{CONF}->{result_index};
}

sub result_index_values {
    my ( $self ) = @_;

    my @results = ();
    foreach my $index(sort {$a->{type} <=> $b->{type}} @{$self->result_index()}){
        push @results, $index->{value};
    }

    return \@results;
}

sub build_registration {
    my ( $self ) = @_;
    
    my $psmd = new SimpleLookupService::Records::Record();
    $psmd->init(type => 'psmetadata');
    $psmd->addField(key => 'psmetadata-ma-locator', value => $self->ma_locator()) if($self->ma_locator());
    $psmd->addField(key => 'psmetadata-uri', value => $self->metadata_uri()) if($self->metadata_uri());
    $psmd->addField(key => 'psmetadata-src-address', value => $self->source()) if($self->source());
    $psmd->addField(key => 'psmetadata-dst-address', value => $self->destination()) if($self->destination());
    $psmd->addField(key => 'psmetadata-measurement-agent', value => $self->measurement_agent()) if($self->measurement_agent());
    $psmd->addField(key => 'psmetadata-tool-name', value => $self->tool_name()) if($self->tool_name());
    $psmd->addField(key => 'psmetadata-eventtypes', value => $self->event_type()) if($self->event_type());
    $psmd->addField(key => 'group-domains', value => $self->domain()) if($self->domain());
    $psmd->addField(key => 'group-communities', value => $self->communities()) if($self->communities());
    foreach my $index(@{$self->result_index()}){
        $psmd->addField(key => 'psmetadata-index-' . $index->{type} , value => $index->{value}) if($index->{type});
    }
    
    return $psmd;
}

sub checksum_prefix {
    return "psmetadata";
}

sub checksum_fields{
    return [
        "ma_locator",
        "metadata_uri",
        "source",
        "destination",
        "measurement_agent",
        "tool_name",
        "event_type",
        "domain",
        "communities",
        "result_index_values",
    ];
}

sub duplicate_checksum_fields {
    my ($self) = @_;
    return $self->checksum_fields();
}

1;
