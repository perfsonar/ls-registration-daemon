package perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::EventTypeIndexerBase;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::EventTypeIndexerBase

=head1 DESCRIPTION

Abstract class for defining classes that index results of a given event type
=cut

use strict;
use warnings;

sub new {
    my $class = shift;

    return bless {}, $class;
}

sub create_index {
    #my($self, $results) = @_;
    die 'Not yet implemented';
}

1;