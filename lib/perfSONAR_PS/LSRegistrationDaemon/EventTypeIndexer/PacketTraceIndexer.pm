package perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::PacketTraceIndexer;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::PacketTraceIndexer

=head1 DESCRIPTION

Class that indexes result of a packet-trace event type. It takes a series of
packet traces and returns a list of unique IPs in the result.
=cut

use base 'perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::EventTypeIndexerBase';

sub create_index {
    my($self, $results) = @_;
    if(!$results){
        return undef;
    }
    
    my %ip_map = ();
    foreach my $result (@{$results}){
        if(!$result || !$result->val || ref($result->val) ne 'ARRAY'){
            next;
        }
        foreach my $hop(@{$result->val}){
            $ip_map{$hop->{ip}} = 1 if($hop->{ip});
        }
    }
    
    my @ip_list = keys %ip_map;
    return \@ip_list;
}

1;