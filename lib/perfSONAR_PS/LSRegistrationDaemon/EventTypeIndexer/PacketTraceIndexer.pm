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
        
        # get the max TTL first. can't assume array length is number of hops since may 
        # have multiple queries. since we want worst case scenario, can't calc factor in
        # after loop either.
        my $max_ttl = 0;
        foreach my $h(@{$result->val}){
            next unless($h->{ttl});
            if($h->{ttl} > $max_ttl){
                $max_ttl = $h->{ttl};
            }
        }
        next unless $max_ttl;
        
        #now iterate through and find distances from src and dest for each hop
        foreach my $hop(@{$result->val}){
            #skip hops without ip and ttl
            next unless($hop->{ip} && $hop->{ttl});
            
            #init ip_map if needed
            unless(exists $ip_map{$hop->{ip}}){
                $ip_map{$hop->{ip}} = {'srcd' => 0, 'dstd' => 0};
            }
            
            #skip if we already have higher or equal hop count for this IP.
            if($ip_map{$hop->{ip}}->{'srcd'} < $hop->{ttl}){
                $ip_map{$hop->{ip}}->{'srcd'} = $hop->{ttl};
            }
            my $dstd = $max_ttl - $hop->{ttl}; #may be 0 since dst shows up in results
            if($ip_map{$hop->{ip}}->{'dstd'} < $dstd){
                $ip_map{$hop->{ip}}->{'dstd'} = $dstd;
            }
        }
    }
    
    #make into a list of strings in format "IP,srd_distance,dst_distance"
    my @ip_list = map {$_ . "," . $ip_map{$_}->{"srcd"} . "," . $ip_map{$_}->{"dstd"}} keys %ip_map;
    return \@ip_list;
}

1;