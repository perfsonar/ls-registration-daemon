package perfSONAR_PS::LSRegistrationDaemon::ToolkitHost;

use base 'perfSONAR_PS::LSRegistrationDaemon::Host';
use Digest::MD5 qw(md5_base64);
use Sys::MemInfo qw(totalmem);

use perfSONAR_PS::Client::LS::PSRecords::PSHost;
use perfSONAR_PS::LSRegistrationDaemon::Interface;
use perfSONAR_PS::LSRegistrationDaemon::ToolkitInterface;
use perfSONAR_PS::Common qw(mergeConfig);

=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;
    
    $self->SUPER::init( $conf );
    
    #set name
    if(!$self->{CONF}->{name} && !$self->{CONF}->{external_address}){
        die "No host_name or external address specified for host";
    }elsif(!$self->{CONF}->{name}){
        $self->{CONF}->{name} = $self->{CONF}->{external_address};
    }
    
    #auto detect memory if not specified
    if(!$self->{CONF}->{memory}){
        $self->{CONF}->{memory} = (&totalmem()/(1024*1024)) . ' MB';
    }
    
    #auto detect os info if not specified
    my ($os_name, $os_version) = ('','');
    unless($self->{CONF}->{os_name} && $self->{CONF}->{os_version}){
        ($os_name, $os_version) = $self->_osinfo();
    }
    if(!$self->{CONF}->{os_name}){
        $self->{CONF}->{os_name} = $os_name;
    }
    if(!$self->{CONF}->{os_version}){
        $self->{CONF}->{os_version} = $os_version;
    }
    
    #determine kernel info
    if(!$self->{CONF}->{os_kernel}){
        $self->{CONF}->{os_kernel} = $self->_os_kernel();
    }
    
    #determine processor info
    my ($proc_speed, $proc_count, $proc_cores) = ('','','');
    unless($self->{CONF}->{processor_speed} && $self->{CONF}->{processor_count} && $self->{CONF}->{processor_cores}){
        ($proc_speed, $proc_count, $proc_cores) = $self->_cpuinfo();
    }
    if(!$self->{CONF}->{processor_speed}){
        $self->{CONF}->{processor_speed} = $proc_speed . ' MHz';
    }
    if(!$self->{CONF}->{processor_count}){
        $self->{CONF}->{processor_count} = $proc_count;
    }
    if(!$self->{CONF}->{processor_cores}){
        $self->{CONF}->{processor_cores} = $proc_cores;
    }
    
    #determine TCP settings
    if(!$self->{CONF}->{tcp_cc_algorithm}){
        $self->{CONF}->{tcp_cc_algorithm} = $self->_call_sysctl("net.ipv4.tcp_congestion_control");
    }
    if(!$self->{CONF}->{tcp_max_buffer}){
        $self->{CONF}->{tcp_max_buffer} = $self->_call_sysctl("net.core.wmem_max") . ' bytes';
    }
    if(!$self->{CONF}->{tcp_autotune_max_buffer}){
        $self->{CONF}->{tcp_autotune_max_buffer} = $self->_max_buffer_auto() . ' bytes';
    }
    
    return 0;
}

sub create_interface {
    my ($self, $type) = @_;
    
    if($type eq 'toolkit'){
        return perfSONAR_PS::LSRegistrationDaemon::ToolkitInterface->new();
    }
    
    return perfSONAR_PS::LSRegistrationDaemon::Interface->new();
}

#sub toolkit_version {
#    my ( $self ) = @_;
#
#    return $self->{CONF}->{toolkit_version};
#}



sub _osinfo(){
    my($self) = @_;
    
    open(FILE, "/etc/redhat-release") or return ('', '');
    my @lines = <FILE>;
    close(FILE);
    if(@lines == 0){
        return ('', '');
    }
    
    chomp $lines[0];
    my @osinfo = split ' release ', $lines[0];
    if(@osinfo != 2){
        return ('', '');
    }
    
    return @osinfo;
}

sub _cpuinfo(){
    my($self) = @_;
    
    my %cpuinfo = (
        speed => '',
        count => '',
        cores => '',
    );
    my %parse_map = (
        'CPU MHz' => 'speed',
        'CPU socket(s)' => 'count',
        'CPU(s)' => 'cores',
    );
    
    my @lscpu = `lscpu`;
    if($?){
        $self->{LOGGER}->warn("Error executing lscpu. Unable to determine CPU info: " . $?);
        return ('','','');
    }
    foreach my $line(@lscpu){
        chomp $line ;
        my @cols = split /\:\s+/, $line;
        next if(@cols != 2);
        
        if($parse_map{$cols[0]}){
            $cpuinfo{$parse_map{$cols[0]}} = $cols[1];
        }
    }
     
    return ($cpuinfo{speed}, $cpuinfo{count}, $cpuinfo{cores});
}

sub _os_kernel {
    my($self) = @_;
    
    my $kernel_type = $self->_call_sysctl("kernel.ostype");
    if(!$kernel_type){
        return '';
    }
    my $kernel_release = $self->_call_sysctl("kernel.osrelease");
    if(!$kernel_release){
        return '';
    }
    
    return "$kernel_type $kernel_release";
}

sub _max_buffer_auto {
    my($self) = @_;
    
    my $sysctl_val = $self->_call_sysctl("net.ipv4.tcp_wmem");
    if(!$sysctl_val){
        return '';
    }
    
    my @parts = split /\s+/, $sysctl_val;
    if(@parts != 3){
        return '';
    }
    
    return $parts[2];
}

sub _call_sysctl {
    my ($self, $var_name) = @_;
    
    my $result = `sysctl $var_name`;
    if($?){
        $self->{LOGGER}->warn("Error executing sysctl: " . $?);
        return '';
    }
    if(!$result){
        return '';
    }
    my @parts = split '=', $result;
    if(@parts != 2){
        return '';
    }
    chomp $parts[1];
    $parts[1] =~ s/^\s+//;
    
    return $parts[1];
}


1;