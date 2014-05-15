package perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::EventTypeIndexerFactory;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::EventTypeIndexerFactory

=head1 DESCRIPTION

Factory that returns an object to index the results of a given event type.
=cut

use strict;
use warnings;

use perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::PacketTraceIndexer;

sub new {
    my $class = shift;

    return bless {}, $class;
}

sub create_indexer {
    my($self, $type) = @_;
    
    if($type eq 'packet-trace'){
        return new perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::PacketTraceIndexer();
    }

    return undef;
}

1;