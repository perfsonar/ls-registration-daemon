# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # Build an el7 machine as the default
  config.vm.define "pslsreg-el7", primary: true, autostart: true do |el7|
    # set box to official CentOS 7 image
    el7.vm.box = "centos/7"
    # explcitly set shared folder to virtualbox type. If not set will choose rsync 
    # which is just a one-way share that is less useful in this context
    el7.vm.synced_folder ".", "/vagrant", type: "virtualbox"
    # Set hostname
    el7.vm.hostname = "pslsreg-el7"
    
    # Enable IPv4. Cannot be directly before or after line that sets IPv6 address. Looks
    # to be a strange bug where IPv6 and IPv4 mixed-up by vagrant otherwise and one 
    #interface will appear not to have an address. If you look at network-scripts file
    # you will see a mangled result where IPv4 is set for IPv6 or vice versa
    el7.vm.network "private_network", ip: "10.0.0.20"
    
    # Setup port forwarding to apache
    el7.vm.network "forwarded_port", guest: 8090, host: "8090", host_ip: "127.0.0.1"
    
    # Enable IPv6. Currently only supports setting via static IP. Address below in the
    # reserved local address range for IPv6
    el7.vm.network "private_network", ip: "fdac:218a:75e5:69c8::20"
    
    #Disable selinux
    el7.vm.provision "shell", inline: <<-SHELL
        sed -i s/SELINUX=enforcing/SELINUX=permissive/g /etc/selinux/config
    SHELL
    
    #reload VM since selinux requires reboot. Requires `vagrant plugin install vagrant-reload`
    el7.vm.provision :reload
    
    #Install all requirements and perform initial setup
    el7.vm.provision "shell", inline: <<-SHELL
    
        ##setup mongodb repo
        cat > /etc/yum.repos.d/mongodb-org-3.4.repo <<EOF
[mongodb-org-3.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\\$releasever/mongodb-org/3.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc    
EOF

        ## install yum dependencies
        yum install -y epel-release
        yum install -y  http://software.internet2.edu/rpms/el7/x86_64/RPMS.main/perfSONAR-repo-0.8-1.noarch.rpm
        yum clean all
        yum install -y perfSONAR-repo-staging perfSONAR-repo-nightly
        yum clean all
        yum install -y gcc \
            kernel-devel \
            kernel-headers \
            dkms \
            make \
            bzip2 \
            perl \
            perl-devel\
            perl-ExtUtils-MakeMaker\
            mongodb-org\
            lookup-service \
            net-tools \
            perl-AppConfig \
            perl-B-Hooks-EndOfScope \
            perl-Business-ISBN \
            perl-Business-ISBN-Data \
            perl-CGI \
            perl-CGI-Ajax \
            perl-CGI-Session \
            perl-Class-Accessor \
            perl-Class-Factory-Util \
            perl-Class-Load \
            perl-Class-Singleton \
            perl-Compress-Raw-Bzip2 \
            perl-Compress-Raw-Zlib \
            perl-Config-General \
            perl-Curses \
            perl-DBD-Pg \
            perl-DBD-SQLite \
            perl-DBI \
            perl-DB_File \
            perl-Data-Dumper \
            perl-Data-OptList \
            perl-Data-UUID \
            perl-Data-Validate-Domain \
            perl-Data-Validate-IP \
            perl-Date-Manip \
            perl-DateTime \
            perl-DateTime-Format-Builder \
            perl-DateTime-Format-ISO8601 \
            perl-DateTime-Format-Strptime \
            perl-DateTime-Locale \
            perl-DateTime-TimeZone \
            perl-Devel-GlobalDestruction \
            perl-Devel-PartialDump \
            perl-Digest \
            perl-Digest-HMAC \
            perl-Digest-MD5 \
            perl-Digest-SHA \
            perl-Dist-CheckConflicts \
            perl-Email-Date-Format \
            perl-Encode-Locale \
            perl-Eval-Closure \
            perl-FCGI \
            perl-File-Listing \
            perl-FreezeThaw \
            perl-Geo-IP \
            perl-HTML-Parser \
            perl-HTML-Tagset \
            perl-HTTP-Cookies \
            perl-HTTP-Daemon \
            perl-HTTP-Date \
            perl-HTTP-Message \
            perl-HTTP-Negotiate \
            perl-Hash-Merge \
            perl-IO-Compress \
            perl-IO-HTML \
            perl-IO-Interface \
            perl-IO-Multiplex \
            perl-IO-Pipely \
            perl-IO-Socket-INET6 \
            perl-IO-Socket-IP \
            perl-IO-Socket-SSL \
            perl-IO-Tty \
            perl-IPC-DirQueue \
            perl-IPC-Run \
            perl-Image-Base \
            perl-Image-Info \
            perl-Image-Xbm \
            perl-Image-Xpm \
            perl-JSON \
            perl-JSON-XS \
            perl-LWP-MediaTypes \
            perl-LWP-Protocol-https \
            perl-Linux-Inotify2 \
            perl-List-MoreUtils \
            perl-Log-Dispatch \
            perl-Log-Dispatch-FileRotate \
            perl-Log-Log4perl \
            perl-MIME-Lite \
            perl-MIME-Types \
            perl-MRO-Compat \
            perl-Mail-Sender \
            perl-Mail-Sendmail \
            perl-MailTools \
            perl-Math-Int64 \
            perl-Module-Implementation \
            perl-Module-Load \
            perl-Module-Runtime \
            perl-Moose \
            perl-Mouse \
            perl-Mozilla-CA \
            perl-Net-CIDR \
            perl-Net-DNS \
            perl-Net-Daemon \
            perl-Net-Domain-TLD \
            perl-Net-HTTP \
            perl-Net-INET6Glue \
            perl-Net-IP \
            perl-Net-LibIDN \
            perl-Net-Netmask \
            perl-Net-SMTP-SSL \
            perl-Net-SSLeay \
            perl-Net-Server \
            perl-Net-Traceroute \
            perl-NetAddr-IP \
            perl-POE \
            perl-Package-DeprecationManager \
            perl-Package-Generator \
            perl-Package-Stash \
            perl-Package-Stash-XS \
            perl-Params-Util \
            perl-Params-Validate \
            perl-PlRPC \
            perl-Pod-POM \
            perl-RPC-XML \
            perl-RPM2 \
            perl-Regexp-Common \
            perl-Socket6 \
            perl-Statistics-Descriptive \
            perl-Sub-Exporter \
            perl-Sub-Exporter-Progressive \
            perl-Sub-Install \
            perl-Sub-Name \
            perl-Sys-Statistics-Linux \
            perl-Sys-Syslog \
            perl-Template-Toolkit \
            perl-TermReadKey \
            perl-Test-Harness \
            perl-Test-Simple \
            perl-TimeDate \
            perl-Try-Tiny \
            perl-Types-Serialiser \
            perl-URI \
            perl-Variable-Magic \
            perl-WWW-RobotRules \
            perl-XML-DOM \
            perl-XML-LibXML \
            perl-XML-NamespaceSupport \
            perl-XML-Parser \
            perl-XML-RegExp \
            perl-XML-SAX \
            perl-XML-SAX-Base \
            perl-XML-Simple \
            perl-YAML-Syck \
            perl-common-sense \
            perl-libwww-perl \
            perl-namespace-clean \
            perl-version \
            perltidy
        
        #make sure lookup-service listens on all interfaces so port forwarding works
        sed -i s/'localhost'/'0.0.0.0'/g /etc/lookup-service/lookupservice.yaml
        
        #enable lookup-service
        systemctl enable mongod
        systemctl start mongod
        systemctl enable lookup-service
        systemctl start lookup-service
        
        ## setup shared folders and files
        if ! [ -d /vagrant/vagrant-data/pslsreg-el7/etc/perfsonar ]; then
            rm -rf /vagrant/vagrant-data/pslsreg-el7/etc/perfsonar
        fi
        if ! [ -L /etc/perfsonar ]; then
            rm -rf /etc/perfsonar
        fi
        mkdir -p /vagrant/vagrant-data/pslsreg-el7/etc/perfsonar
        ln -fs /vagrant/vagrant-data/pslsreg-el7/etc/perfsonar /etc/perfsonar
        
        #copy default config
        cp -f /vagrant/etc/lsregistrationdaemon.conf /etc/perfsonar/lsregistrationdaemon.conf
        echo "" >> /etc/perfsonar/lsregistrationdaemon.conf
        echo "ls_instance http://127.0.0.1:8090/lookup/records"  >> /etc/perfsonar/lsregistrationdaemon.conf
        echo "" >> /etc/perfsonar/lsregistrationdaemon.conf
    SHELL
  end
  
  # Runs on all hosts before they are provisioned. Creates user and inits /var directories
  config.vm.provision "shell", inline: <<-SHELL
    /usr/sbin/groupadd perfsonar 2> /dev/null || :
    /usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :
    mkdir -p /var/lib/perfsonar/lsregistrationdaemon
    chown -R perfsonar:perfsonar /var/lib/perfsonar
    mkdir -p /var/log/perfsonar
    chown perfsonar:perfsonar /var/log/perfsonar
  SHELL
end
