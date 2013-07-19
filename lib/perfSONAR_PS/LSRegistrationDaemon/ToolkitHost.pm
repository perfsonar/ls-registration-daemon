package perfSONAR_PS::LSRegistrationDaemon::ToolkitHost;

use strict;
use warnings;

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
    
    #set name
    if(!$conf->{name} && !$conf->{external_address}){
        die "No host_name or external address specified for host";
    }elsif(!$conf->{name}){
        $conf->{name} = $conf->{external_address};
    }
    
    #auto detect memory if not specified
    if(!$conf->{memory}){
        $conf->{memory} = (&totalmem()/(1024*1024)) . ' MB';
    }
    
    #auto detect os info if not specified
    my ($os_name, $os_version) = ('','');
    unless($conf->{os_name} && $conf->{os_version}){
        ($os_name, $os_version) = $self->_osinfo();
    }
    if(!$conf->{os_name}){
        $conf->{os_name} = $os_name;
    }
    if(!$conf->{os_version}){
        $conf->{os_version} = $os_version;
    }
    
    #determine kernel info
    if(!$conf->{os_kernel}){
        $conf->{os_kernel} = $self->_os_kernel();
    }
    
    #determine processor info
    my ($proc_speed, $proc_count, $proc_cores) = ('','','');
    unless($conf->{processor_speed} && $conf->{processor_count} && $conf->{processor_cores}){
        ($proc_speed, $proc_count, $proc_cores) = $self->_cpuinfo();
    }
    if(!$conf->{processor_speed}){
        $conf->{processor_speed} = $proc_speed . ' MHz';
    }
    if(!$conf->{processor_count}){
        $conf->{processor_count} = $proc_count;
    }
    if(!$conf->{processor_cores}){
        $conf->{processor_cores} = $proc_cores;
    }
    
    #determine TCP settings
    if(!$conf->{tcp_cc_algorithm}){
        $conf->{tcp_cc_algorithm} = $self->_call_sysctl("net.ipv4.tcp_congestion_control");
    }
    if(!$conf->{tcp_max_buffer_send}){
        $conf->{tcp_max_buffer_send} = $self->_call_sysctl("net.core.wmem_max") . ' bytes';
    }
    if(!$conf->{tcp_max_buffer_recv}){
        $conf->{tcp_max_buffer_recv} = $self->_call_sysctl("net.core.rmem_max") . ' bytes';
    }
    if(!$conf->{tcp_autotune_max_buffer_send}){
        $conf->{tcp_autotune_max_buffer_send} = $self->_max_buffer_auto("net.ipv4.tcp_wmem") . ' bytes';
    }
    if(!$conf->{tcp_autotune_max_buffer_recv}){
        $conf->{tcp_autotune_max_buffer_recv} = $self->_max_buffer_auto("net.ipv4.tcp_rmem") . ' bytes';
    }
    if(!$conf->{tcp_max_backlog}){
        $conf->{tcp_max_backlog} = $self->_call_sysctl("net.core.netdev_max_backlog");
    }
    
    #determine toolkit version
    if(!$conf->{toolkit_version_file}){
        #set default
        $conf->{toolkit_version_file} = "/opt/perfsonar_ps/toolkit/scripts/NPToolkit.version";
    }
    if ( open( OUTPUT, "-|", $conf->{toolkit_version_file} ) ) {
        my $version = <OUTPUT>;
        close( OUTPUT );
        if($version){
            chomp( $version );
            $conf->{toolkit_version} = $version;
        }
    }
    
    return $self->SUPER::init( $conf );
}

sub create_interface {
    my ($self, $type) = @_;
    
    if($type eq 'toolkit'){
        return perfSONAR_PS::LSRegistrationDaemon::ToolkitInterface->new();
    }
    
    return perfSONAR_PS::LSRegistrationDaemon::Interface->new();
}

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
    my($self, $sysctl_var) = @_;
    
    my $sysctl_val = $self->_call_sysctl($sysctl_var);
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
