package perfSONAR_PS::LSRegistrationDaemon::Signature;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';
use perfSONAR_PS::Client::LS::PSRecords::PSSignature;
use perfSONAR_PS::Client::LS::PSQueryObjects::PSSignatureQueryObject;
use SimpleLookupService::Client::Query;
use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Common qw(mergeConfig);


sub known_variables {
    my ($self) = @_;

    my @variables = $self->SUPER::known_variables();

    push @variables, (
        { variable => "x509certificateurl", type => "scalar" },
    );

    return @variables;
}

=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;
    unless ($conf->{x509certificateurl}){
        $self->{LOGGER}->error("certificate url is required");
    	return -1;
    }

    return $self->SUPER::init( $conf );
}

##
# Overload to lookup contact prior to trying to register
sub refresh {
    my ( $self ) = @_;
    
    #lookup host
    my $signature_query = perfSONAR_PS::Client::LS::PSQueryObjects::PSSignatureQueryObject->new();
    $signature_query->init();
    $signature_query->setCertificate($self->x509certificateurl()) if $self->certificate();
    
    my $query_client = SimpleLookupService::Client::Query->new();
    $query_client->init(server => $self->{LS_CLIENT}, query => $signature_query);
    my($result_code, $results) = $query_client->query();
    if($result_code != 0 || @{$results} == 0){
        #not found
        $self->{STATUS} = 'UNREGISTERED';
        $self->{NEXT_REFRESH} = 0 if($self->{NEXT_REFRESH} == -1);
    }elsif($self->{KEY}){
        #found and we already have a uri
        my $last_uri = '';
        foreach my $signature(@{$results}){
            $last_uri = $signature->getRecordUri();
            last if($last_uri eq $self->{KEY});
        }
        if($last_uri ne $self->{KEY}){
            $self->delete_key();
            $self->{KEY} = $last_uri;
            $self->add_key();
        }
    }else{
        #found and we have never seen before
         $self->{KEY} = $results->[0]->getRecordUri();
         $self->{NEXT_REFRESH} = -1; #this means someone else registered it
    }
    
    $self->SUPER::refresh() if($self->{NEXT_REFRESH} != -1);
}

sub is_up {
    #die "Subclass must implement is_up"; 
    return 1;
}


sub certificate {
    my ( $self ) = @_;

    return $self->{CONF}->{x509certificateurl};
}


sub build_registration {
    my ( $self ) = @_;
    
    my $signature = new perfSONAR_PS::Client::LS::PSRecords::PSSignature();
    $signature->init(
        x509certificate => $self->certificate()
    );
    
    return $signature;
}

sub checksum_prefix {
    return "signature";
}

sub checksum_fields {
    return [
        "certificate",
    ];
}

sub duplicate_checksum_fields {
    return [
        "certificate"
    ];
}

1;
